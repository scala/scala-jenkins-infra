// for use with ssh -p 8022 admin@scala-ci.typesafe.com groovysh 
import jenkins.model.Jenkins
import org.jenkinsci.plugins.*
Jenkins.instance.setSecurityRealm(new GithubSecurityRealm('https://github.com/', 'https://api.github.com', '{{github_api_client_id}}', '{{github_api_client_secret}}', 'read:org,user:email'))
Jenkins.instance.setAuthorizationStrategy(new GithubAuthorizationStrategy('adriaanm, retronym, lrytz, SethTisue, smarter, DarkDimius, chef, scala-jenkins, szeiger, dwijnand', true, true, false, 'scala', true, false, true, true))
Jenkins.instance.save()
