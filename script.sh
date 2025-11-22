#!/bin/bash
#
# Honeypot Deployment Menu
# Script version 1.0 — Updated: 22-11-2025
#

set -euo pipefail

while true; do

    OPTION=$(whiptail --title "Main Menu" --menu "Choose an option:" 20 70 13 \
        "1" "Install prerequisites" \
        "2" "Install Docker" \
        "3" "Install EWSPoster" \
        "4" "Install Honeypot Stack"  \
        "5" "Exit" \
        3>&1 1>&2 2>&3)

    exitstatus=$?

    if [ $exitstatus -ne 0 ]; then
        echo "User cancelled."
        exit 1
    fi

    case "$OPTION" in

    1)
        ########################################################################
        # Install prerequisites
        ########################################################################
        sudo apt-get update -y
        sudo apt-get upgrade -y
        sudo apt-get install -y wget curl nano git whiptail
        ;;

    2)
        ########################################################################
        # Install Docker
        ########################################################################
        if command -v docker >/dev/null 2>&1; then
            whiptail --title "Docker" --msgbox "Docker is already installed." 8 60
        else
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            sudo systemctl enable docker.service
            sudo systemctl enable containerd.service
        fi
        ;;

    3)
        ########################################################################
        # Install EWSPoster
        ########################################################################
        if [[ -d "ewsposter" || -d "ewsposter_data" ]]; then
            whiptail --title "EWSPoster" \
            --msgbox "Directory 'ewsposter' or 'ewsposter_data' already exists. Please check the folder before proceeding." 8 78
        else
            sudo apt-get install -y python3-pip
            mkdir -p ewsposter_data/log ewsposter_data/spool ewsposter_data/json
            # git clone --branch mongodb https://github.com/yevonnaelandrew/ewsposter
            # cd ewsposter
            # sudo pip3 install -r requirements.txt
            # sudo pip3 install influxdb psutil docker
        fi
        ;;

    4)
        ########################################################################
        # Install Honeypot Stack (Cowrie, Conpot, Dionaea, Honeytrap)
        ########################################################################

        # Harden SSH (optional)
        sudo sed -i 's/#Port 22/Port 22888/' /etc/ssh/sshd_config
        sudo systemctl restart ssh || sudo service sshd restart

        # Pull images
        sudo docker pull dtagdevsec/cowrie:24.04.1
        sudo docker pull dtagdevsec/conpot:24.04.1
        sudo docker pull dtagdevsec/dionaea:24.04.1
        sudo docker pull dtagdevsec/honeytrap:24.04.1

        # Create volumes
        sudo docker volume create cowrie-var
        sudo docker volume create cowrie-etc
        sudo docker volume create honeytrap
        sudo docker volume create conpot
        sudo docker volume create dionaea

        # Cowrie
        sudo docker run -d \
            -p 22:22/tcp -p 23:23/tcp \
            -v cowrie-etc:/cowrie/cowrie-git/etc \
            -v cowrie-var:/cowrie/cowrie-git/var \
            --cap-drop=ALL --read-only \
            --restart unless-stopped \
            --name cowrie \
            dtagdevsec/cowrie:24.04.1

        # Dionaea
        sudo docker run -d \
            -p 21:21 -p 42:42 -p 69:69/udp -p 80:80 \
            -p 135:135 -p 443:443 -p 445:445 -p 1433:1433 \
            -p 1723:1723 -p 1883:1883 -p 3306:3306 -p 5060:5060 \
            -p 5060:5060/udp -p 5061:5061 -p 11211:11211 \
            -v dionaea:/opt/dionaea \
            --restart unless-stopped \
            --name dionaea \
            dtagdevsec/dionaea:24.04.1

        # Honeytrap
        sudo docker run -d \
            -p 2222:2222 -p 8545:8545 -p 5900:5900 -p 25:25 \
            -p 5037:5037 -p 631:631 -p 389:389 -p 6379:6379 \
            -v honeytrap:/home \
            --restart unless-stopped \
            --name honeytrap \
            dtagdevsec/honeytrap:24.04.1

        # Conpot
        sudo docker run -d \
            -v conpot:/data \
            -p 8000:8800 -p 10201:10201 -p 5020:5020 \
            -p 16100:16100/udp -p 47808:47808/udp \
            -p 6230:6230/udp -p 2121:2121 \
            -p 6969:6969/udp -p 44818:44818 \
            --restart always \
            --name conpot \
            dtagdevsec/conpot:24.04.1
        ;;

    5)
        ########################################################################
        # Exit
        ########################################################################
        echo "Goodbye!"
        exit 0
        ;;

    *)
        whiptail --title "Error" --msgbox "Invalid selection." 8 60
        ;;
    esac

done
