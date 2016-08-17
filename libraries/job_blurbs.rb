require 'cgi'

module ScalaJenkinsInfra
  module JobBlurbs
    # works both for
    def stdRefSpec
      # can't use "+refs/pull/${_scabot_pr}/head:refs/remotes/${repo_user}/pr/${_scabot_pr}/head " because _scabot_pr isn't always set, and don't know how to default it to *
      "+refs/heads/*:refs/remotes/${repo_user}/* +refs/pull/*/head:refs/remotes/${repo_user}/pr/*/head"
    end

    def xmlSafe(str)
      CGI.escapeHTML(str)
    end

    @@concurrentDefaults = {
      :maxConcurrentPerNode => 3,
      :maxConcurrentTotal   => 0,
      :throttleEnabled      => "true",
      :throttleOption       => "project"
    }

    def selectConcurrentOptions(options)
      # plain ruby does not have a subset/intersect/slice on map??? http://stackoverflow.com/questions/9025277/how-do-i-extract-a-sub-hash-from-a-hash
      options.select{|k, v| @@concurrentDefaults.key?(k)}
    end

    def properties(repoUser, repoName, repoRef, params, concurrentOptions)
      stringPar =
        """
        <hudson.model.StringParameterDefinition>
          <name>%{name}</name>
          <description>%{desc}</description>
          <defaultValue>%{default}</defaultValue>
        </hudson.model.StringParameterDefinition>""".gsub(/        /, '')

      paramDefaults = {:default => nil}

      concurr = @@concurrentDefaults.merge(concurrentOptions)

      concurrProps = concurrentOptions.empty? ? '' : """<hudson.plugins.throttleconcurrents.ThrottleJobProperty plugin=\"throttle-concurrents@1.8.4\">
          <maxConcurrentPerNode>#{ concurr[:maxConcurrentPerNode] }</maxConcurrentPerNode>
          <maxConcurrentTotal>#{   concurr[:maxConcurrentTotal]   }</maxConcurrentTotal>
          <throttleEnabled>#{      concurr[:throttleEnabled]      }</throttleEnabled>
          <throttleOption>#{       concurr[:throttleOption]       }</throttleOption>
        </hudson.plugins.throttleconcurrents.ThrottleJobProperty>
      """

      """<properties>
        <com.tikal.hudson.plugins.notification.HudsonNotificationProperty plugin=\"notification@1.7\">
          <endpoints>
            <com.tikal.hudson.plugins.notification.Endpoint>
              <protocol>HTTP</protocol>
              <format>JSON</format>
              <url>#{node['master']['jenkins']['notifyUrl']}</url>
              <event>all</event>
              <timeout>30000</timeout>
            </com.tikal.hudson.plugins.notification.Endpoint>
          </endpoints>
        </com.tikal.hudson.plugins.notification.HudsonNotificationProperty>
        <hudson.model.ParametersDefinitionProperty>
          <parameterDefinitions>
            #{scmParams(repoUser, repoName, repoRef)}
            #{params.map { |param| stringPar % paramDefaults.merge(param) }.join("\n")}
          </parameterDefinitions>
        </hudson.model.ParametersDefinitionProperty>
        #{concurrProps}
      </properties>"""
    end

    def flowProject(options = {})
      # chef's still stuck on ruby 1.9 (on our amazon linux)
      repoUser    = options[:repoUser]
      repoName    = options.fetch(:repoName, nil)
      repoRef     = options[:repoRef]
      dsl         = options[:dsl]
      description = options.fetch(:description, '')
      params      = options.fetch(:params, [])
      concurrent  = options.fetch(:concurrent, true)
      buildNameScript = options.fetch(:buildNameScript, setBuildNameScript)

      <<-EOX
      <description>#{xmlSafe(description)}</description>
      #{properties(repoUser, repoName, repoRef, params, selectConcurrentOptions(options))}
      <scm class="hudson.scm.NullSCM"/>
      <canRoam>true</canRoam>
      <concurrentBuild>#{concurrent}</concurrentBuild>
      <dsl>#{xmlSafe(buildNameScript+"\n\n"+dsl)}</dsl>
      EOX
    end

    def githubProject(options = {})
      # chef's still stuck on ruby 1.9 (on our amazon linux)
      repoUser            = options[:repoUser]
      repoName            = options.fetch(:repoName, nil)
      repoRef             = options[:repoRef]
      description         = options.fetch(:description, '')
      nodeRestriction     = options.fetch(:nodeRestriction, nil)
      params              = options.fetch(:params, [])
      refspec             = options.fetch(:refspec, stdRefSpec)
      cleanWorkspace      = options.fetch(:cleanWorkspace, true)
      concurrent          = options.fetch(:concurrent, true)
      buildTimeoutMinutes = options.fetch(:buildTimeoutMinutes, 1440)
      buildNameScript     = options.fetch(:buildNameScript, setBuildNameScript)

      jvmFlavor  = options[:jvmFlavor]
      jvmVersion = options[:jvmVersion]
      jvmSelectScript = ""

      if jvmFlavor && jvmVersion
        params.concat([
          {:name => "jvmFlavor",  :default => jvmFlavor,  :desc => "Java flavor to use (oracle/openjdk)."},
          {:name => "jvmVersion", :default => jvmVersion, :desc => "Java version to use (6/7/8)."}
        ])
        jvmSelectScript=jvmSelect
      end

      restriction =
      """<assignedNode>%{nodes}</assignedNode>
      <canRoam>false</canRoam>""".gsub(/      /, '')

      def env(name)
        "${ENV,var=&quot;#{name}&quot;}"
      end

      <<-EOX
        <description>#{xmlSafe(description)}</description>
        #{properties(repoUser, repoName, repoRef, params, selectConcurrentOptions(options))}
        #{scmBlurb(refspec, cleanWorkspace)}
        #{restriction % {nodes: xmlSafe(nodeRestriction)} if nodeRestriction}
        <concurrentBuild>#{concurrent}</concurrentBuild>
        <builders>
          #{groovySysScript(buildNameScript)}
          #{scriptBuild(jvmSelectScript)}
        </builders>
        <buildWrappers>
          <hudson.plugins.build__timeout.BuildTimeoutWrapper plugin="build-timeout@1.14.1">
             <strategy class="hudson.plugins.build_timeout.impl.AbsoluteTimeOutStrategy">
               <timeoutMinutes>#{buildTimeoutMinutes}</timeoutMinutes>
             </strategy>
             <operationList/>
          </hudson.plugins.build__timeout.BuildTimeoutWrapper>
          <hudson.plugins.ansicolor.AnsiColorBuildWrapper plugin="ansicolor@0.4.1">
            <colorMapName>xterm</colorMapName>
          </hudson.plugins.ansicolor.AnsiColorBuildWrapper>
          <hudson.plugins.logfilesizechecker.LogfilesizecheckerWrapper plugin="logfilesizechecker@1.2">
            <setOwn>false</setOwn>
            <maxLogSize>0</maxLogSize>
            <failBuild>true</failBuild>
          </hudson.plugins.logfilesizechecker.LogfilesizecheckerWrapper>
        </buildWrappers>
      EOX
    end

    def scmBlurb(refspec, cleanWorkspace)
      <<-EOH.gsub(/^ {8}/, '')
        <scm class="hudson.plugins.git.GitSCM" plugin="git@2.2.1">
          <configVersion>2</configVersion>
          <userRemoteConfigs>
            <hudson.plugins.git.UserRemoteConfig>
              <name>${repo_user}</name>
              <refspec>#{refspec}</refspec>
              <url>https://github.com/${repo_user}/${repo_name}.git</url>
            </hudson.plugins.git.UserRemoteConfig>
          </userRemoteConfigs>
          <branches>
            <hudson.plugins.git.BranchSpec>
              <name>${repo_ref}</name>
            </hudson.plugins.git.BranchSpec>
          </branches>
          <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
          <submoduleCfg class="list"/>
          <extensions>
          #{ cleanWorkspace ? "<hudson.plugins.git.extensions.impl.CleanCheckout/>" : "" }
          </extensions>
        </scm>
      EOH
    end

    def versionedJob(repo, branch, name)
      "#{repo}-#{branch}-#{name.gsub(/\//, '-')}"
    end

    def job(name)
      versionedJob(@repo, @branch, name)
    end

    def jvmSelect
      <<-EOH.gsub(/^      /, '')
      if [ -f /usr/local/share/jvm/jvm-select ]; then
        source /usr/local/share/jvm/jvm-select
        jvmSelect $jvmFlavor $jvmVersion
      else
        echo "WARNING: jvm-select not present. using system default Java"
      fi
      EOH
    end

    def scriptBuild(setup)
      <<-EOH.gsub(/^      /, '')
      <hudson.tasks.Shell>
        <command>#!/bin/bash -ex
      #{setup}
      source scripts/#{@scriptName}
        </command>
      </hudson.tasks.Shell>
      EOH
    end

    def setBuildNameScript
      <<-EOH.gsub(/^      /, '')
      repo_user = build.buildVariableResolver.resolve("repo_user")
      repo_name = build.buildVariableResolver.resolve("repo_name")
      repo_ref  = build.buildVariableResolver.resolve("repo_ref").take(12)
      build.setDisplayName("[${build.number}] $repo_user/$repo_name\#$repo_ref")
      EOH
    end

    def setValidateBuildNameScript
      <<-EOH.gsub(/^      /, '')
      repo_user   = build.buildVariableResolver.resolve("repo_user")
      repo_name   = build.buildVariableResolver.resolve("repo_name")
      repo_ref    = build.buildVariableResolver.resolve("repo_ref").take(6)
      _scabot_pr  = build.buildVariableResolver.resolve("_scabot_pr")
      build.setDisplayName("[${build.number}] $repo_user/$repo_name\#$_scabot_pr at $repo_ref")
      EOH
    end

    def setReleaseBuildNameScript
      <<-EOH.gsub(/^      /, '')
      repo_user = build.buildVariableResolver.resolve("repo_user")
      repo_name = build.buildVariableResolver.resolve("repo_name")
      repo_ref  = build.buildVariableResolver.resolve("repo_ref").take(12)
      ver = params["SCALA_VER_BASE"] + params["SCALA_VER_SUFFIX"]
      build.setDisplayName("[${build.number}] Scala dist ${ver} $repo_user/$repo_name\#$repo_ref")
      EOH
    end


    def groovySysScript(script)
      <<-EOH.gsub(/^      /, '')
      <hudson.plugins.groovy.SystemGroovy plugin="groovy">
        <scriptSource class="hudson.plugins.groovy.StringScriptSource">
          <command>#{xmlSafe(script)}</command>
        </scriptSource>
      </hudson.plugins.groovy.SystemGroovy>
      EOH
    end

    def scmUserParam(user)
      <<-EOH.gsub(/^ {8}/, '')
        <hudson.model.StringParameterDefinition>
          <name>repo_user</name>
          <description>The github username for the repo to clone.</description>
          <defaultValue>#{user}</defaultValue>
        </hudson.model.StringParameterDefinition>
      EOH
    end

    def scmNameParam(name)
      name == nil ? '' : <<-EOH.gsub(/^ {8}/, '')
       <hudson.model.StringParameterDefinition>
         <name>repo_name</name>
         <description>The name of the repo to clone.</description>
         <defaultValue>#{name}</defaultValue>
       </hudson.model.StringParameterDefinition>
      EOH
    end

    def scmRefParam(ref)
      <<-EOH.gsub(/^ {8}/, '')
        <hudson.model.StringParameterDefinition>
          <name>repo_ref</name>
          <description>The git ref at ${repo_user}/${repo_name} to build.</description>
          <defaultValue>#{ref}</defaultValue>
        </hudson.model.StringParameterDefinition>
      EOH
    end

    def scmParams(user, name, ref)
      scmUserParam(user) + scmNameParam(name) + scmRefParam(ref)
    end
  end
end
