#!/bin/bash
set -e

SVN_BASE_DIR=/var/lib/svn
IMPORT_EXPORT_PATH=/tmp/import_export

SVN_HOSTNAME=${SVN_HOSTNAME:=svn.example.com}
SVN_LDAP_PASSWORD=${SVN_LDAP_PASSWORD:=novatech}

# ************************************************************
# Options passed to the docker container to run scripts
# ************************************************************
# svn    : Starts apache running. This is the containers default
# backup : archives the svn repositories into the IMPORT_EXPORT_PATH
# import : import and create svn repositories from arguments and the IMPORT_EXPORT_PATH

case ${1} in
    svn)
        # Set the server name
        if [[ ! -z "${SVN_HOSTNAME}" ]]; then
            echo >&2 "Setting SVN Hostname: ${SVN_HOSTNAME}"
            # change any value of SVN_HOSTNAME to the value
            sed -i 's|SVN_HOSTNAME|'${SVN_HOSTNAME}'|' \
                /etc/apache2/sites-available/000-default-ssl.conf \
                /etc/apache2/sites-available/000-default.conf \
                /etc/websvn/config.php
            # update the ServerName line
            sed -i 's|ServerName .*$|ServerName '${SVN_HOSTNAME}'|' \
                /etc/apache2/sites-available/000-default-ssl.conf \
                /etc/apache2/sites-available/000-default.conf
#            sed -i 's|ServerName .*$|ServerName '${SVN_HOSTNAME}'|' \
#                /etc/websvn/config.php
            # Update the LDAP proxyagent password
            sed -i 's|AuthLDAPBindPassword.*$|AuthLDAPBindPassword '${SVN_LDAP_PASSWORD}'|' \
                /etc/apache2/sites-available/000-websvn.conf \
                /etc/apache2/mods-available/ldap.conf
        fi
        echo >&2 "Adding SVN repositories:"
        # Create apache config entries for each available repository
        repo_conf_dir=/etc/apache2/sites-available/dav_svn
        [[ -e ${repo_conf_dir} ]] && \
            rm -rf ${repo_conf_dir}
        mkdir ${repo_conf_dir}
        svn_repos="$(cd ${SVN_BASE_DIR};ls -1d *)"
        for repo_path in ${svn_repos} ; do
            if [[ ! -f ${repo_path}/format ]]; then
                echo >&2 "  ==> <SKIPPED>    ${repo_path}"
                continue
            fi
            repo_name=$(basename ${repo_path})
            echo >&2 "  ==> [${repo_name}]    ${repo_path}"
            cat << EOF > ${repo_conf_dir}/${repo_name}.conf
<Location /${repo_name}>
    DAV svn
    SVNPath ${SVN_BASE_DIR}/${repo_name}
    AuthType Basic
    AuthBasicProvider ldap
    AuthName "svn repository"
    AuthLDAPURL "ldap://ldap/ou=user,dc=novatech?uid?sub?(objectClass=Person)"
    AuthLDAPBindAuthoritative off
    AuthLDAPSearchAsUser on
    AuthLDAPCompareAsUser on
    AuthLDAPBindDN cn=proxyagent,dc=novatech
    AuthLDAPBindPassword ${SVN_LDAP_PASSWORD}
    AuthLDAPGroupAttribute memberUid
    AuthLDAPGroupAttributeIsDN off
    <RequireAll>
        Require valid-user
        Require ssl
        Require ip 172.16.0.0/16 192.168.0.0/16
        <RequireAny>
            Require ldap-group cn=%{SERVER_NAME},ou=group,dc=novatech
            Require ldap-group cn=${repo_name},cn=%{SERVER_NAME},ou=group,dc=novatech
        </RequireAny>
    </RequireAll>
</Location>
EOF
        done
        chown -R www-data:www-data ${SVN_BASE_DIR}
        # Apache gets grumpy about PID files pre-existing
        rm -f /var/run/apache2/apache2.pid
        # Start apache
        exec apache2 -D FOREGROUND
        ;;

    backup)
        # commands export the SVN repositories for backup
        for repo_path in ${SVN_BASE_DIR}/*
        do
            [[ ! -f ${repo_path}/format ]] && continue
            repo_name=$(basename ${repo_path})
            [[ -f ${IMPORT_EXPORT_PATH}/${repo_name}.svndump.gz ]] && \
                rm -f ${IMPORT_EXPORT_PATH}/${repo_name}.svndump.gz
            /usr/bin/svnadmin dump ${repo_path} | gzip -9 > \
                ${IMPORT_EXPORT_PATH}/${repo_name}.svndump.gz
        done
        ;;

    import)
        # ignore first argument and get list of repositories to create
        shift
        SVN_REPOSITORIES=(${*})
        # make certain the SVN directory exists
        [[ ! -d ${SVN_BASE_DIR} ]] && mkdir -p ${SVN_BASE_DIR}
        # Create SVN repositories
        for repo_name in ${SVN_REPOSITORIES[*]} ; do
            [[ ! -f ${SVN_BASE_DIR}/${repo_name}/format ]] && \
                svnadmin create --fs-type=fsfs ${SVN_BASE_DIR}/${repo_name}
        done
        # Import svndump archived SVN repositories
        for filename in ${IMPORT_EXPORT_PATH}/*.svndump.gz ; do
            [[ ! -e ${filename} ]] && continue
            repo_name=$(basename ${filename} | sed -e 's/\.svndump\.gz//')
            [[ -d ${SVN_BASE_DIR}/${repo_name} ]] && \
                rm -rf ${SVN_BASE_DIR}/${repo_name}
            /usr/bin/svnadmin create ${SVN_BASE_DIR}/${repo_name}
            /bin/gunzip --stdout ${filename} | \
                /usr/bin/svnadmin load ${SVN_BASE_DIR}/${repo_name}
        done
        # change permissions on svn repositories
        chown -R www-data:www-data ${SVN_BASE_DIR}
        ;;

    *)
        # run some other command in the docker container
        exec "$@"
        ;;
esac

