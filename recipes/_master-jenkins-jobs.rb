#
# Cookbook Name:: scala-jenkins-infra
# Recipe:: _master-config-jobs
#
# Copyright 2014, Typesafe, Inc.
#
# All rights reserved - Do Not Redistribute
#


ruby_block 'set private key' do
  block do
    node.run_state[:jenkins_private_key] = chef_vault_item("master", "scala-jenkins-keypair")['private_key']
  end
end


# TODO: is there no shorter way??
class Blurbs
  include ScalaJenkinsInfra::JobBlurbs
end

# turn template path into jenkins job name
def templDesc(user, repo, branch, path)
  blurbs = Blurbs.new

  m = path.match(/templates\/default\/jobs\/#{user}\/(.*)\.xml\.erb$/)
  if m == nil
    []
  else
    relativePath = m.captures.first

    [ { :templatePath => "jobs/#{user}/#{relativePath}.xml.erb",
        :scriptName   => "jobs/#{relativePath}",
        :jobName      => blurbs.versionedJob(repo, branch, relativePath),
        :user         => user,
        :repo         => repo, # the main repo (we may refer to other repos under the same user in these jobs)
        :branch       => branch,
      }
    ]
  end
end

# TODO #8 #5: jobs in integrate/ (test IDE integration, matrix, core-community)
# if all integration builds succeed, staged merge commit can be pushed to main repo
# matrix:
#  - buildArgs:
#    - rangepos
#    - checkinit
#  - os:
#     - windows
#     - linux
#  - jdk:
#     - 6
#     - 7
#     - 8
#     - 9
# core-community: sbt, ensime, modules, ide,...

def expandJobTemplates(user, repo, branch)
  node.run_context.cookbook_collection["scala-jenkins-infra"].manifest[:templates]
    .flat_map { |mani| templDesc(user, repo, branch, mani['path']) }
    .each do | desc |

    xml = File.join(Chef::Config[:file_cache_path], "#{desc[:jobName]}.xml")

    template xml do
      variables(desc)

      source desc[:templatePath]
      helpers(ScalaJenkinsInfra::JobBlurbs)
    end

    jenkins_job desc[:jobName] do
      config xml
    end
  end
end

# TODO: make consistent with scabot.conf.erb by construction
# (each github user for which we create jobs should have a corresponding top-level section in scabot.conf)
# create scala-$branch-$jobName for every template under jobs/
%w{ 2.11.x 2.12.x }.each do | branch |
  expandJobTemplates("scala", "scala", branch)
end


# TODO #10: make a view for each top-level directory under jobs/ that lists all jobs under it (scala-2.11.x-integrate, scala-2.11.x-release, scala-2.11.x-validate)
# https://issues.jenkins-ci.org/browse/JENKINS-8927
def viewXML(viewPrefix)
  <<-EOH.gsub(/^    /, '')
    <listView>
      <owner class="hudson" reference="../../.."/>
      <name>#{viewPrefix}</name>
      <filterExecutors>false</filterExecutors>
      <filterQueue>false</filterQueue>
      <properties class="hudson.model.View$PropertyList"/>
      <jobNames>
        <comparator class="hudson.util.CaseInsensitiveComparator"/>
      </jobNames>
      <jobFilters/>
      <columns>
        <hudson.views.StatusColumn/>
        <hudson.views.WeatherColumn/>
        <hudson.views.JobColumn/>
        <hudson.views.LastSuccessColumn/>
        <hudson.views.LastFailureColumn/>
        <hudson.views.LastDurationColumn/>
        <hudson.views.BuildButtonColumn/>
      </columns>
      <includeRegex>#{viewPrefix}-.*</includeRegex>
      <recurse>false</recurse>
      <statusFilter>true</statusFilter>
    </listView>
  EOH
end
