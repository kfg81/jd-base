#!/bin/bash
#
# Copyright (C) 2021 Patrick⭐
#
# 以 Docker 容器的方式一键安装 jd-base。
#
clear

echo "
     ██╗██████╗     ██████╗  ██████╗  ██████╗██╗  ██╗███████╗██████╗ 
     ██║██╔══██╗    ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗
     ██║██║  ██║    ██║  ██║██║   ██║██║     █████╔╝ █████╗  ██████╔╝
██   ██║██║  ██║    ██║  ██║██║   ██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗
╚█████╔╝██████╔╝    ██████╔╝╚██████╔╝╚██████╗██║  ██╗███████╗██║  ██║
 ╚════╝ ╚═════╝     ╚═════╝  ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝
                                                                     
            ==== Create by 老竭力 | Mod by Patrick⭐ ====
"
DockerImage="ohmypatrick/jd-base:v3"
ShellName=$0
ShellDir=$(cd "$(dirname "$0")";pwd)
ContainerName=""
PanelPort=""
WorkDir="${ShellDir}/onekey-jd-docker-workdir"
JdDir=""
ConfigDir=""
LogDir=""
ScriptsDir=""

GetImageType="Online"
HasImage=false
NewImage=true
DelContainer=false

NeedDirConfig=""
NeedDirLog=""
NeedDirScripts=""

log() {
    echo -e "\e[32m$1 \e[0m"
}

inp() {
    echo -e "\e[33m$1 \e[0m"
}

warn() {
    echo -e "\e[31m$1 \e[0m"
}


# 检查 Docker 环境
Install_Docker() {
    if [ -x "$(command -v docker)" ]; then
       log "Docker 已安装!"
    else
        if [ -r /etc/os-release ]; then
            lsb_dist="$(. /etc/os-release && echo "$ID")"
        fi
        if [ $lsb_dist == "openwrt" ]; then
            warn "OpenWrt 环境请自行安装 Docker"
            exit 1
        else
            log "安装 Docker 环境..."
            curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
            log "Docker 环境安装完成!"
            systemctl enable docker
            systemctl start docker
        fi
    fi
}
Install_Docker

warn "\n注意如果你什么都不清楚，建议所有选项都直接回车，使用默认选择！！！\n"

#
# 收集配置信息
#

# 检测镜像是否存在
Check_Image() {
    if [ ! -z "$(docker images -q $DockerImage 2> /dev/null)" ]; then
        HasImage=true
        inp "检测到先前已经存在的镜像，是否创建新的镜像：\n1) 是[默认]\n2) 不需要"
        echo -n -e "\e[33m输入您的选择->\e[0m"
        read update
        if [ "$update" = "2" ]; then
            NewImage=false
        fi
    fi
}
Check_Image

Choose_GetImageType() {
    inp "\n选择镜像获取方式：\n1) 在线获取[默认]\n2) 本地生成"
    echo -n -e "\e[33m输入您的选择->\e[0m"
    read update
    if [ "$update" = "2" ]; then
        GetImageType="Local"
    fi
}
Choose_GetImageType

# 检测容器是否存在
Check_ContainerName() {
    if [ ! -z "$(docker ps --format "{{.Names}}" | grep -w $ContainerName 2> /dev/null)" ]; then
        inp "\n检测到先前已经存在的容器，是否删除先前的容器：\n1) 是[默认]\n2) 不要"
        echo -n -e "\e[33m输入您的选择->\e[0m"
        read update
        if [ "$update" = "2" ]; then
            log "选择了不删除先前的容器，需要重新输入容器名称"
            Input_ContainerName
        else
            DelContainer=true
        fi
    fi
}

# 输入容器名称
Input_ContainerName() {
    echo -n -e "\n\e[33m请输入要创建的Docker容器名称[默认为：jd]->\e[0m"
    read container_name
    if [ -z "$container_name" ]; then
        ContainerName="jd"
    else
        ContainerName=$container_name
    fi
    Check_ContainerName 
}
Input_ContainerName

# 输入端口号
Input_PanelPort() {
    echo -n -e "\n\e[33m请输入控制面板端口号[默认为：5678]->\e[0m"
    read panel_port
    if [ -z "$panel_port" ]; then
        PanelPort="5678"
    else
        PanelPort=$panel_port
    fi
    inp "如发现端口冲突，请自行检查端口占用情况！"
}
Input_PanelPort

# 配置文件目录

Need_ConfigDir() {
    inp "\n是否需要映射配置文件目录：\n1) 是[默认]\n2) 否"
    echo -n -e "\e[33m输入您的选择->\e[0m"
    read need_config_dir
    if [ "$need_config_dir" = "2" ]; then
        NeedDirConfig=''
    else
        NeedDirConfig="-v $ConfigDir:/jd/config"
        mkdir -p $ConfigDir
    fi
}

Need_LogDir() {
    inp "\n是否需要映射日志文件目录：\n1) 是[默认]\n2) 否"
    echo -n -e "\e[33m输入您的选择->\e[0m"
    read need_log_dir
    if [ "$need_log_dir" = "2" ]; then
        NeedDirLog=''
    else
        NeedDirLog="-v $LogDir:/jd/log"
        mkdir -p $LogDir
    fi
}

Need_ScriptsDir() {
    inp "\n是否需要映射js脚本目录：\n1) 是\n2) 否[默认]"
    echo -n -e "\e[33m输入您的选择->\e[0m"
    read need_scripts_dir
    if [ "$need_scripts_dir" = "1" ]; then
        NeedDirScripts="-v $ScriptsDir:/jd/scripts"
        mkdir -p $ScriptsDir
    fi
}

Need_Dir() {
    inp "\n是否需要映射文件目录：\n1) 是[默认]\n2) 否"
    echo -n -e "\e[33m输入您的选择->\e[0m"
    read need_dir
    if [ "$need_dir" = "2" ]; then
        log "选择了不映射文件目录"
    else
        echo -e "\n\e[33m请输入配置文件保存的绝对路径,直接回车为 $ShellDir/jd-docker :\e[0m"
        read jd_dir
        if [ -z "$jd_dir" ]; then
            JdDir=$ShellDir/jd-docker
        else
            JdDir=$jd_dir
        fi
        ConfigDir=$JdDir/config
        LogDir=$JdDir/log
        ScriptsDir=$JdDir/scripts
        Need_ConfigDir
        Need_LogDir
        Need_ScriptsDir
    fi
}
Need_Dir

#
# 配置信息收集完成，开始安装
#

if [ $NewImage = true ]; then
    log "\n正在获取新镜像..."
    if [ $HasImage = true ]; then
        docker image rm -f $DockerImage
    fi
    if [ $GetImageType = "Local" ]; then
        rm -fr $WorkDir
        mkdir -p $WorkDir
        wget -q https://github.com/RikudouPatrickstar/jd-base/raw/v3/docker/Dockerfile -O $WorkDir/Dockerfile
        docker build -t $DockerImage $WorkDir > $LogDir/NewImage.log
        rm -fr $WorkDir
    else
        docker pull $DockerImage
    fi
fi

if [ $DelContainer = true ]; then
    log "\n2.2.删除先前的容器"
    docker stop $ContainerName > /dev/null
    docker rm $ContainerName > /dev/null
fi

log "\n创建容器并运行"
docker run -dit \
    $NeedDirConfig \
    $NeedDirLog \
    $NeedDirScripts \
    -p $PanelPort:5678 \
    --name $ContainerName \
    --hostname jd \
    --restart always \
    $DockerImage

log "\n下面列出所有容器"
docker ps

log "\n安装已经完成。\n请访问 http://<ip>:5678 进行配置\n初始用户名：admin，初始密码：password"
rm -f $ShellDir/$ShellName

