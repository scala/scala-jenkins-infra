require 'cgi'

module ScalaJenkinsInfra
  module JobBlurbs
    def prRefSpec
      "+refs/pull/${_scabot_pr}/head:refs/remotes/${repo_user}/pr/${_scabot_pr}/head"
    end

    def stdRefSpec
      "+refs/heads/*:refs/remotes/${repo_user}/*"
    end

    def properties(repoUser, repoName, repoRef, params)
      stringPar =
        """
        <hudson.model.StringParameterDefinition>
          <name>%{name}</name>
          <description>%{desc}</description>
          <defaultValue>%{default}</defaultValue>
        </hudson.model.StringParameterDefinition>""".gsub(/        /, '')

      paramDefaults = {:default => nil}

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

      <<-EOX
      <description>#{CGI.escapeHTML(description)}</description>
      #{properties(repoUser, repoName, repoRef, params)}
      <scm class="hudson.scm.NullSCM"/>
      <canRoam>true</canRoam>
      <concurrentBuild>#{concurrent}</concurrentBuild>
      <dsl>#{CGI.escapeHTML(dsl)}</dsl>
      EOX
    end

    def githubProject(options = {})
      # chef's still stuck on ruby 1.9 (on our amazon linux)
      repoUser        = options[:repoUser]
      repoName        = options.fetch(:repoName, nil)
      repoRef         = options[:repoRef]
      description     = options.fetch(:description, '')
      nodeRestriction = options.fetch(:nodeRestriction, nil)
      params          = options.fetch(:params, [])
      refspec         = options.fetch(:refspec, stdRefSpec)
      concurrent      = options.fetch(:concurrent, true)
      timeoutMinutesElasticDefault = options.fetch(:timeoutMinutesElasticDefault, 150)

      restriction =
      """<assignedNode>%{nodes}</assignedNode>
      <canRoam>false</canRoam>""".gsub(/      /, '')

      def env(name)
        "${ENV,var=&quot;#{name}&quot;}"
      end

      <<-EOX
        <description>#{CGI.escapeHTML(description)}</description>
        #{properties(repoUser, repoName, repoRef, params)}
        #{scmBlurb(refspec)}
        #{restriction % {nodes: nodeRestriction} if nodeRestriction}
        <concurrentBuild>#{concurrent}</concurrentBuild>
        <builders>#{scriptBuild}</builders>
        <buildWrappers>
          <hudson.plugins.build__timeout.BuildTimeoutWrapper plugin="build-timeout@1.14.1">
            <strategy class="hudson.plugins.build_timeout.impl.ElasticTimeOutStrategy">
              <timeoutPercentage>150</timeoutPercentage>
              <numberOfBuilds>3</numberOfBuilds>
              <timeoutMinutesElasticDefault>#{timeoutMinutesElasticDefault}</timeoutMinutesElasticDefault>
            </strategy>
            <operationList/>
          </hudson.plugins.build__timeout.BuildTimeoutWrapper>
        </buildWrappers>
      EOX
    end

    def scmBlurb(refspec)
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
            <hudson.plugins.git.extensions.impl.CleanCheckout/>
          </extensions>
        </scm>
      EOH
    end

    def versionedJob(version, name)
      "scala-#{version}-#{name.gsub(/\//, '-')}"
    end

    def job(name)
      versionedJob(@version, name)
    end

    def scriptBuild
      <<-EOH.gsub(/^      /, '')
      <hudson.tasks.Shell>
        <command>#!/bin/bash -ex
      source scripts/#{@scriptName}
        </command>
      </hudson.tasks.Shell>
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
