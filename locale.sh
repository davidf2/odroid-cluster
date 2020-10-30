#! /bin/bash

set_language() {
        
		locale="$1"

        if [ $# -ne 1 ]; then
                echo "You need to enter a language in odroid_cluster.conf"
                exit 1
        fi

        if [ $(cat /usr/share/i18n/SUPPORTED | grep ^"$locale".UTF-8 | wc -l) -eq 0 ]; then
                echo "Incorrect language"
                exit 1
        fi

        if [ $(grep "source /etc/default/locale" /etc/profile | wc -l) -eq 0 ]; then
                echo "source /etc/default/locale" >> /etc/profile
        fi

        if [ $(grep "source /etc/default/locale" /etc/bash.bashrc | wc -l) -eq 0 ]; then
                echo "source /etc/default/locale" >> /etc/bash.bashrc
        fi

        # Instal.lem el nou idioma
        locale-gen "$locale".utf8

        # Seleccionem el nou idioma
        #update-locale LANG="$locale".UTF-8 LANGUAGE
        localectl set-locale LANG="$locale".UTF-8 LANGUAGE="$locale".UTF-8:"$(echo $locale | cut -d_ -f1)"

        # Actualitza les varaibles LANG i LANGUAGE
        source /etc/default/locale

        su $master_name -c 'source /etc/default/locale'

        # Instal.lem dependencies del nou idioma per tal de traduir-ho tot.
        apt-get install $(check-language-support -l "$locale") -y
}

set_layout() {
	
	layout="$1"
	variant="$2"
	
    apt install xrdp -y

    if [ $# -ne 2 ]; then
            echo -e "It is necessary to pass 2 arguments, the first corresponding to the \nlayout and the second to the variant"
            exit 1
    fi
	
	if [ "$layout" == "$variant" ]; then
		variant="basic"
	fi

    if [ $(([ "$DISPLAY" ] || [ "$WAYLAND_DISPLAY" ] || [ "$MIR_SOCKET" ] && echo 1) || echo 0) -eq 1 ]; then
        if [ $(echo "$DISPLAY") = ":0" ]; then
            setxkbmap -layout $layout -variant $variant
        fi
    fi

	if [ $(grep "setxkbmap -layout $layout -variant $variant" /etc/profile | wc -l) -eq 1 ]; then
            sed -i '/^setxkbmap/d' /etc/profile
            echo "if [ \$(([ "\$DISPLAY" ] || [ "\$WAYLAND_DISPLAY" ] || [ "\$MIR_SOCKET" ] && echo 1) || echo 0) -eq 1 ]; then
        if [ \$(echo "\$DISPLAY") = ":0" ]; then
            setxkbmap -layout $layout -variant $variant
        fi
    fi" >> /etc/profile
    fi

    if [ $(grep "setxkbmap -layout $layout -variant $variant" /etc/bash.bashrc | wc -l) -eq 1 ]; then
             sed -i '/^setxkbmap/d' /etc/bash.bashrc
            echo "if [ \$(([ "\$DISPLAY" ] || [ "\$WAYLAND_DISPLAY" ] || [ "\$MIR_SOCKET" ] && echo 1) || echo 0) -eq 1 ]; then
        if [ \$(echo "\$DISPLAY") = ":0" ]; then
            setxkbmap -layout $layout -variant $variant
        fi
    fi" >> /etc/bash.bashrc
    fi
}