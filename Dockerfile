FROM fedora:latest
MAINTAINER Stephan Günther <steph.guenther@gmail.com>

# prepare system and install stuff 
RUN yum upgrade -y && yum install -y haproxy supervisor golang git vim

# install sentinel
ENV GOPATH /usr/share/go
RUN mkdir -p $GOPATH
RUN go get -v github.com/BlueDragonX/sentinel

# configure supervisor
COPY supervisord.conf /etc/supervisord.conf
COPY supervisor-haproxy.conf /etc/supervisord.d/haproxy.conf
COPY supervisor-sentinel.conf /etc/supervisord.d/sentinel.conf

# add startup scripts
COPY run_haproxy.sh /usr/local/bin/run_haproxy
COPY run_sentinel.sh /usr/local/bin/run_sentinel

# go!
CMD ["supervisord", "-n", "-c", "/etc/supervisord.conf"]
