#!/bin/sh
#
# 脚本的作用是基于Omnibus安装方式的gitlab，12以后的版本进行备份和远程恢复。
# 可以通过cron实现每日git低使用期间进行备份，比如凌晨4点以后
# 警告：您的 gitlab.rb 和 gitlab-secrets.json 文件包含敏感数据，
# 并且不包含在此备份中。您将需要这些文件来恢复备份。
# =====================================================

BACKUP_FILE='script-cron'
TARGET_SERVER='10.12.54.29'
TARGET_SERVER_SSH_PORT=63008
BACK_PID='/opt/gitlab/embedded/service/gitlab-rails/tmp/backup_restore.pid'

exiterr() { echo "Error: $1" >&2; exit 1; }

check_root() {
  if [ "$(id -u)" != 0 ]; then
    exiterr "Script must be run as root. Try 'sudo sh $0'"
  fi
}

backup_gitlab() {
    check_root
    gitlab-backup create BACKUP=$BACKUP_FILE
    ls -lh /var/opt/gitlab/backups/
    scp -P $TARGET_SERVER_SSH_PORT /var/opt/gitlab/backups/${BACKUP_FILE}_gitlab_backup.tar root@$TARGET_SERVER:/tmp/
    scp -P $TARGET_SERVER_SSH_PORT /etc/gitlab/gitlab.rb root@$TARGET_SERVER:/tmp/
    scp -P $TARGET_SERVER_SSH_PORT /etc/gitlab/gitlab-secrets.json root@$TARGET_SERVER:/tmp/
}

restore_gitlab() {
    check_root
    cp /tmp/${BACKUP_FILE}_gitlab_backup.tar /var/opt/gitlab/backups/${BACKUP_FILE}_gitlab_backup.tar
    gitlab-ctl reconfigure
    gitlab-ctl start
    chown git:git /var/opt/gitlab/backups/${BACKUP_FILE}_gitlab_backup.tar
    gitlab-ctl stop puma
    gitlab-ctl stop sidekiq
    gitlab-backup restore BACKUP=${BACKUP_FILE} force=yes
    cp /tmp/gitlab.rb /etc/gitlab/gitlab.rb
    cp /tmp/gitlab-secrets.json /etc/gitlab/gitlab-secrets.json
    gitlab-ctl restart
    gitlab-rake gitlab:check SANITIZE=true
}

echo $1

if [ $1 = "backup" ]
then
    echo "Start backup"
    backup_gitlab
elif [ $1 = "restore" ]
then
    echo "Start restore"
    restore_gitlab
else
    exiterr "Error input, $0. backup/restore"
fi


exit 0