Copyright (C) 2024 Trustees of Dartmouth College

This project is licensed under the terms of the GNU General Public License (GPL), version 3 or later.

For alternative licensing options, please contact the Dartmouth College OpenAV project team.

# raspi-image-customizer

This project is for the purpose of automating the customization of RapiOS images. In mass deployments this is to avoid having to visit Pis after deployment.

# How to Run

This is a container you instantiate and pipe a RaspiOS file into it, and out stderr comes the customized version of it. On the piped in image will be executed a script you provide. Either via the $SCRIPT environment variable, or by mounting in a directory containing a file called "script.sh" at /data in the container. This script can only make modifications to the filesystem on the image. You may also want to run actual commands when the Pi boots for the first time, do so with the $FIRSTBOOTSCRIPT environment variable, or by mounting /data/firstbootscript.sh.

Download the img file for the RaspiOS version you want to customize. Then run the customizer as such:

```sudo docker run --rm -i --cap-add SYS_ADMIN --privileged --platform linux/amd64 --device /dev/loop0 --cpus="1" -e SCRIPT="echo 'test'" -e FIRSTBOOTSCRIPT="echo 'first boot'" --memory="500m" --name=raspi-image-customizer ghcr.io/dartmouth-openav/raspi-image-customizer:latest < ~/Downloads/20XX-XX-XX-raspios-bookworm-arm64-lite.img 2> ~/Downloads/20XX-XX-XX-raspios-bookworm-arm64-customized.img```

> [!NOTE]  
> The customizer mounts the image on /tmp/root, so if you wanted to change /etc/my/config.json for example, your script should refer to it at /tmp/root/etc/my/config.json

> [!WARNING]
> Because the image comes out of the container on stderr, any errors that might have occured in your script will not be visible on the terminal. Either your script is known to be flawless, or make sure you `head -1 20XX-XX-XX-raspios-bookworm-arm64-customized.img`. If everything went well you will see binary gibberish. Otherwise, you'll get the errors to be addressed. Yes, this is an eclectic use of stderr, I don't remember why I did this years ago but I'm pretty sure there was a good reason :).

> [!WARNING]
> You are running a container retrieved from the internet with `--cap-add SYS_ADMIN` and `--privileged`, this is necessary to mount the original RaspiOS image inside the container and make modifications to it. You should trust the respo/registry you want to grant such privileges to.




# Script.sh Snippets

Over the years I had to figure out how to do several things in this customizer, these are just RaspiOS commands but they took a bit to figure out sometimes, I hope they can be useful to others. Notably, the official Raspberry Pi Imager today let you customize network settings, locale, and SSH service/keys on an image. So this project and some of the snippets are less useful. But it still doesn't let you run "user data" type scripts as one would when automating the deployments of VMs.

## add NTP server

```echo "NTP=time.google.com" >> /tmp/root/etc/systemd/timesyncd.conf```

## remove first run dialog

```rm /tmp/root/etc/xdg/autostart/piwiz.desktop > /dev/null 2>&1```



# Firstbootscript.sh Snippets

## Set keyboard locale
```raspi-config nonint do_configure_keyboard en_US```

## Set wifi locale
```raspi-config nonint do_wifi_country US```

## Install Zerotier & join network
```echo "> installing Zerotier"
curl -s https://install.zerotier.com/ | sudo bash
echo "> joining Zerotier network"
zerotier-cli join <MY_ZEROTIER_NETWORK_ID>```