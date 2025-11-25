#!/bin/bash
#
# Honeypot Deployment Menu
# Script version 1.2 — Updated: 25-11-2025
#

set -euo pipefail

while true; do

    OPTION=$(whiptail --title "Main Menu" --menu "Choose an option:" 20 70 13 \
        "1" "Install prerequisites" \
        "2" "Install Docker" \
        "3" "Install EWSPoster" \
        "4" "Install Honeypot Stack"  \
        "5" "Install Logstash" \
        "6" "Exit" \
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
        sudo apt update -y
        sudo apt upgrade -y
        sudo apt install -y wget curl nano git whiptail apt-transport-https curl gnupg 
        sudo wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo gpg --dearmor -o /usr/share/keyrings/elasticsearch-keyring.gpg
        sudo echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/8.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-8.x.list
        sudo apt update
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
            # mkdir -p ewsposter_data/log ewsposter_data/spool ewsposter_data/json
            # git clone --branch mongodb https://github.com/yevonnaelandrew/ewsposter
            # cd ewsposter
            # sudo pip3 install -r requirements.txt
            # sudo pip3 install influxdb psutil docker
            git clone https://github.com/yevonnaelandrew/ewsposter && cd ewsposter && sudo pip3 install -r requirements.txt && cd ..
            mkdir ewsposter_data ewsposter_data/log ewsposter_data/spool ewsposter_data/json
            current_dir=$(pwd)
            nodeid=$(hostname)
            sed -i "s|/home/ubuntu|$current_dir|g" ewsposter/ews.cfg
            sed -i "s|ASEAN-ID-SGU|$nodeid|g" ewsposter/ews.cfg
            (crontab -l 2>/dev/null; echo "*/5 * * * * cd ${current_dir}/ewsposter && /usr/bin/python3 ews.py >> ews.log 2>&1") | sudo crontab -
        fi
        ;;

    4)
        ########################################################################
        # Install Honeypot Stack (Cowrie, Conpot, Dionaea, Honeytrap)
        ########################################################################

        # Harden SSH (optional)
        sudo sed -i 's/#Port 22/Port 22888/' /etc/ssh/sshd_config
        sudo systemctl restart ssh || sudo service sshd restart
        
        # ==========================
        # Pull Images
        # ==========================
        sudo docker pull cowrie/cowrie:latest
        sudo docker pull honeynet/conpot:latest
        sudo docker pull cowrie/dionaea:latest
        sudo docker pull honeytrap/honeytrap:latest
        
        # ==========================
        # Create Docker Volumes
        # ==========================
        sudo docker volume create cowrie-var
        sudo docker volume create cowrie-etc
        sudo docker volume create honeytrap
        sudo docker volume create conpot
        sudo docker volume create dionaea
        
        # ==========================
        # Create Host Log Directories
        # ==========================
        sudo mkdir -p /srv/honeypots/cowrie/log
        sudo mkdir -p /srv/honeypots/dionaea/log
        sudo mkdir -p /srv/honeypots/honeytrap/log
        sudo mkdir -p /srv/honeypots/conpot/log
        
        # ==========================
        # Fix Permissions
        # ==========================
        sudo chown 1000:1000 /srv/honeypots/cowrie/log
        sudo chown 1000:1000 /srv/honeypots/dionaea/log
        sudo chown 1000:1000 /srv/honeypots/honeytrap/log
        sudo chown 1000:1000 /srv/honeypots/conpot/log
        
        # ==========================
        # Run Dionaea
        # ==========================
        docker run -d \
          --name dionaea \
          -p 21:21 \
          -p 42:42 \
          -p 69:69/udp \
          -p 80:80 \
          -p 135:135 \
          -p 443:443 \
          -p 445:445 \
          -p 1433:1433 \
          -p 1723:1723 \
          -p 1883:1883 \
          -p 3306:3306 \
          -p 5060:5060 \
          -p 5060:5060/udp \
          -p 5061:5061 \
          -p 11211:11211 \
          -v dionaea:/opt/dionaea \
          -v /srv/honeypots/dionaea/log:/opt/dionaea/var/lib/dionaea \
          --restart unless-stopped \
          cowrie/dionaea:latest
        
        # ==========================
        # Run Cowrie
        # ==========================
        docker run -d \
          --name cowrie \
          -p 22:22 \
          -p 23:23 \
          -v cowrie-etc:/cowrie/cowrie-git/etc \
          -v cowrie-var:/cowrie/cowrie-git/var \
          -v /srv/honeypots/cowrie/log:/cowrie/cowrie-git/var/log/cowrie \
          --cap-drop=ALL \
          --cap-add=NET_BIND_SERVICE \
          --restart unless-stopped \
          cowrie/cowrie:latest
        
        # ==========================
        # Run Honeytrap
        # ==========================
        docker run -d \
          --name honeytrap \
          -p 2222:2222 \
          -p 8545:8545 \
          -p 5900:5900 \
          -p 25:25 \
          -p 5037:5037 \
          -p 631:631 \
          -p 389:389 \
          -p 6379:6379 \
          -v honeytrap:/home \
          -v /srv/honeypots/honeytrap/log:/home \
          --restart unless-stopped \
          honeytrap/honeytrap:latest
        
        # ==========================
        # Run Conpot
        # ==========================
        docker run -d \
          --name conpot \
          -p 8000:8800 \
          -p 10201:10201 \
          -p 5020:5020 \
          -p 16100:16100/udp \
          -p 47808:47808/udp \
          -p 6230:6230/udp \
          -p 2121:2121 \
          -p 6969:6969/udp \
          -p 44818:44818 \
          -v conpot:/data \
          -v /srv/honeypots/conpot/log:/data \
          --restart always \
          honeynet/conpot:latest
        ;;

    5)
        ########################################################################
        # Install Logstash
        ########################################################################
        
        sudo apt install logstash -y
        sudo systemctl daemon-reload
        sudo systemctl enable logstash
   		sudo systemctl start logstash
        ;;
    6)
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
