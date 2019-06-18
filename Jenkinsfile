#!/usr/bin/groovy

def label = "worker-${UUID.randomUUID().toString()}"

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


// INPUT PARAMETERS

parameters([
    gitParameter(name: 'BRANCH_NAME', defaultValue: 'master', selectedValue: 'DEFAULT', type: 'PT_BRANCH'),
    booleanParam(name: 'CAN_DOCKER_BUILD_AND_PUSH',defaultValue: true, description: 'build and push docker image'),
    booleanParam(name: 'CAN_DEPLOY_TO_DEV',defaultValue: true, description: 'deploy to dev')
   ])
podTemplate(label: label, serviceAccount: 'jenkins', containers: [
  containerTemplate(name: 'jnlp', image: 'lachlanevenson/jnlp-slave:3.10-1-alpine', args: '${computer.jnlpmac} ${computer.name}', workingDir: '/home/jenkins', resourceRequestCpu: '200m', resourceLimitCpu: '300m', resourceRequestMemory: '256Mi', resourceLimitMemory: '512Mi'),
  containerTemplate(name: 'netcore22', image: 'mcr.microsoft.com/dotnet/core/sdk:2.2', ttyEnabled: true),
  containerTemplate(name: 'docker', image: 'docker:18.09.6', command: 'cat', ttyEnabled: true),  
  containerTemplate(name: 'helm', image: 'lachlanevenson/k8s-helm:v2.6.0', command: 'cat', ttyEnabled: true), 
],
volumes: [
  hostPathVolume(mountPath: '/var/run/docker.sock', hostPath: '/var/run/docker.sock'),
  hostPathVolume(mountPath: '/home/jenkins/.nuget/packages', hostPath: '/home/.nuget/packages/')
]){
    node(label) {
        def dockerImageName ="aspnetcore-kube-devops"
        def dockerRegistry ="index.docker.io"
        def dockerRepo = "morining"
        def versionNumber = sh(
        script: 'head -1 CHANGELOG',
        returnStdout: true).trim()
        def imageTag = versionNumber + "." + sh(
        script: 'date +%y%m%d%H%M',
        returnStdout: true).trim()
        def registryCredsId = "docker_regirstry_creds"


    stage('check out') {
        checkout scm: [$class: 'GitSCM', branches: [[name: "refs/heads/${params.BRANCH}"]]] 
    }
  
    stage('unit test') { 
    
    }

    stage('build'){
        container('netcore22') {
        sh """
        cd src
        dotnet restore
        dotnet build
        dotnet publish -c Release -o publish 
        """
    }
  }

    stage("docker build && docker push"){
        container('docker') {
            withCredentials([[$class          : 'UsernamePasswordMultiBinding', credentialsId: registryCredsId,
            usernameVariable: 'USERNAME', passwordVariable: 'PASSWORD']]) {
            sh "docker login -u ${env.USERNAME} -p ${env.PASSWORD} ${dockerRegistry}"
            println "登陆docker registry 成功！"
            sh """
            docker --version
            echo $shortGitCommit
            docker build -t ${dockerRegistry}/${dockerRepo}/${dockerImageName}:${imageTag} -t ${dockerRegistry}/${dockerRepo}/${dockerImageName}:latest .                            
            docker push ${dockerRegistry}/${dockerRepo}/${dockerImageName}:${imageTag}
            docker push ${dockerRegistry}/${dockerRepo}/${dockerImageName}:${imageTag}
            """
            }
        }
    }

    stage("deploy"){
        container('helm') {
        helmDeploy(
        chartDir:chartDir,
        namespace:config.app.namespace,
        name:config.app.name)}
    }
}
}
