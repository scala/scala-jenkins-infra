require 'cgi'

module ScalaJenkinsInfra
  module JobBlurbs
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

    def githubProject(options = {})
      # chef's still stuck on ruby 1.9 (on our amazon linux)
      repoUser        = options[:repoUser]
      repoName        = options[:repoName]
      repoRef         = options[:repoRef]
      description     = options.fetch(:description, '')
      nodeRestriction = options.fetch(:nodeRestriction, nil)
      params          = options.fetch(:params, [])

      restriction =
      """<assignedNode>%{nodes}</assignedNode>
      <canRoam>false</canRoam>""".gsub(/      /, '')

      def env(name)
        "${ENV,var=&quot;#{name}&quot;}"
      end

      <<-EOX
        <description>#{CGI.escapeHTML(description)}</description>
        #{properties(repoUser, repoName, repoRef, params)}
        <org.jenkinsci.plugins.buildnamesetter.BuildNameSetter plugin="build-name-setter@1.3">
          <template>[${BUILD_NUMBER}] of #{env(repoUser)}/#{env(repoName)}\##{env(repoRef)}</template>
        </org.jenkinsci.plugins.buildnamesetter.BuildNameSetter>
        #{scmBlurb}
        #{restriction % {nodes: nodeRestriction} if nodeRestriction}
      EOX
    end

    def scmBlurb
      <<-EOH.gsub(/^ {8}/, '')
        <scm class="hudson.plugins.git.GitSCM" plugin="git@2.2.1">
          <configVersion>2</configVersion>
          <userRemoteConfigs>
            <hudson.plugins.git.UserRemoteConfig>
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
      <<-EOH.gsub(/^ {8}/, '')
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
