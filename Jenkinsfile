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
properties([
    parameters([
        gitParameter(name: 'BRANCH_NAME', defaultValue: 'master', selectedValue: 'DEFAULT', type: 'PT_BRANCH'),
        booleanParam(name: 'CAN_DOCKER_BUILD_AND_PUSH',defaultValue: true, description: 'build and push docker image'),
        booleanParam(name: 'CAN_DEPLOY_TO_DEV',defaultValue: true, description: 'deploy to dev')
   ])
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

    stage('check out') {
        checkout scm
        sh "git checkout ${params.BRANCH_NAME}" 
    }

        def dockerImageName ="aspnetcore-kube-devops"
        def dockerRegistry ="index.docker.io"
        def dockerRepo = "morining"
        
        def pwd = pwd()
        def chartDir = "${pwd}/charts/aspnetcore-kube-devops"
        def versionNumber = sh(
        script: 'head -1 CHANGELOG',
        returnStdout: true).trim()
        def imageTag = versionNumber + "." + sh(
        script: 'date +%y%m%d%H%M',
        returnStdout: true).trim()
        def registryCredsId = "docker_regirstry_creds"

        def kubeNamespace = "demo"
        def helmAppName = "aspnetcore-kube-devops"
  
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
            sh "docker login -u ${env.USERNAME} -p ${env.PASSWORD}"
            println "登陆docker registry 成功！"
            sh """
            docker --version
            docker build -t ${dockerRepo}/${dockerImageName}:${imageTag} -t ${dockerRepo}/${dockerImageName}:latest .                            
            docker push ${dockerRepo}/${dockerImageName}:${imageTag}
            docker push ${dockerRepo}/${dockerImageName}:${imageTag}
            """
            }
        }
    }

    stage("deploy"){
        container('helm') {
        helmDeploy(
        chartDir:chartDir,
        namespace:helmAppName,
        name:kubeNamespace)}
    }
}
}
