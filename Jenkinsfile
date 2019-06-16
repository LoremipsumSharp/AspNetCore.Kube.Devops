#!/usr/bin/groovy

def label = "worker-${UUID.randomUUID().toString()}"
def buildNumber = env.BUILD_NUMBER.toString()

def helmLint(String chartDir) {
    println "校验 chart 模板"
    sh "helm lint ${chartDir}"
}


def helmDeploy(Map args) {
    helmLint(args.chartDir)
    if (args.dry_run) {
        println "Running dry-run deployment"
        sh "helm upgrade --dry-run --install ${args.name} ${args.chartDir}  --namespace=${namespace}"
    } else {
        println "Running deployment"
        // reimplement --wait once it works reliable
        sh "helm upgrade --install ${args.name} ${args.chartDir}  --namespace=${namespace}"

        // sleeping until --wait works reliably
        sleep(20)

        echo "Application ${args.name} successfully deployed. Use helm status ${args.name} to check"
    }
}



podTemplate(label: label, serviceAccount: 'jenkins', containers: [
  containerTemplate(name: 'jnlp', image: 'lachlanevenson/jnlp-slave:3.10-1-alpine', args: '${computer.jnlpmac} ${computer.name}', workingDir: '/home/jenkins', resourceRequestCpu: '200m', resourceLimitCpu: '300m', resourceRequestMemory: '256Mi', resourceLimitMemory: '512Mi'),
  containerTemplate(name: 'netcore22', image: 'mcr.microsoft.com/dotnet/core/sdk:2.2', ttyEnabled: true),
  containerTemplate(name: 'docker', image: 'docker:18.09.6', command: 'cat', ttyEnabled: true),  
  containerTemplate(name: 'helm', image: 'lachlanevenson/k8s-helm:v2.6.0', command: 'cat', ttyEnabled: true),
  containerTemplate(name: 'kubectl', image: 'lachlanevenson/k8s-kubectl:latest', command: 'cat', ttyEnabled: true, privileged: false)  
],
volumes: [
  hostPathVolume(mountPath: '/var/run/docker.sock', hostPath: '/var/run/docker.sock'),
  hostPathVolume(mountPath: '/home/jenkins/.nuget/packages', hostPath: '/home/.nuget/packages/')
]){
    node(label) {

        def repo = checkout scm
        def gitCommit = repo.GIT_COMMIT
        def gitBranch = repo.GIT_BRANCH
        def shortGitCommit = "v-${gitCommit[0..6]}"
        def pwd = pwd()
        def chartDir = "${pwd}/charts"
        def inputFile = readFile('Jenkinsfile.json')
        def config = new groovy.json.JsonSlurperClassic().parseText(inputFile)
     
        
        stage('Run unit test') {  
            println "开始单元测试..."           
        }

        stage('Build') {
            println "开始构建..."  
            container('netcore22') {
                sh """
                    cd src
                    dotnet restore
                    dotnet build
                    dotnet publish -c Release -o publish 
                """
            }
        }
        
        stage("Build and push docker image") {
            println "开始构建并发布docker镜像..."
            container('docker') {
                withCredentials([[$class          : 'UsernamePasswordMultiBinding', credentialsId: config.app.docker.registry_creds_id,
                        usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD']]) {
                            sh "docker login -u ${env.USERNAME} -p ${env.PASSWORD} ${config.app.docker.registry}"
                            println "登陆docker registry 成功！"
                            sh """
                            docker --version
                            echo $shortGitCommit
                            docker build -t ${config.app.docker.registry}/${config.app.docker.repo}/aspnetcore-kube-devops:$shortGitCommit -t ${config.app.docker.registry}/${config.app.docker.repo}/aspnetcore-kube-devops:latest .                            
                            docker push ${config.app.docker.registry}/${config.app.docker.repo}/aspnetcore-kube-devops:$shortGitCommit
                            docker push ${config.app.docker.registry}/${config.app.docker.repo}/aspnetcore-kube-devops:latest
                            """
                        }
            }
        }
    

        stage('Deploy') {
             println "开始发布应用..."
             container('helm') {
                 helmDeploy(
                     chartDir:chartDir,
                     namespace:config.app.namespace,
                     name:config.app.name
                 )
             }

        }
    }    
}