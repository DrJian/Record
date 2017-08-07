# .bashrc

# User specific aliases and functions



# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi
#PS1='\[\e[01;35m\]\u@\[\e[01;32m\]${HOSTNAME%.baidu*}:\[\e[01;35m\]\w \[\e[37;36m\]\$ \[\e[31;1m\]'
#PS1="\[\033[01;31m\]\u\[\033[00m\]@\[\033[01;32m\]\h\[\033[00m\][\[\033[01;33m\]\t\[\033[00m\]]:\[\033[01;34m\]`pwd`\[\033[00m\]\n$ "
export PS1='\u@${HOSTNAME}:`pwd` \n$ '
# 自用alias

