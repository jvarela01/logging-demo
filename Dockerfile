FROM registry.access.redhat.com/ubi8/ubi

LABEL io.k8s.description="A basic Apache HTTP Server" \
      io.k8s.display-name="Simple Apache HTTP Server" \
      io.openshift.expose-services="8080-tcp" \
      io.openshift.tags="apache, httpd"

ENV DOCROOT=/var/www/html

EXPOSE 8080

VOLUME /var/log/httpd

RUN yum install -y --disableplugin=subscription-manager httpd && \
    yum clean all -y --disableplugin=subcription-manager && \
    rm -rf /run/httpd && mkdir /run/httpd && \
    sed -i "s/Listen 80/Listen 8080/g" /etc/httpd/conf/httpd.conf && \
    chgrp -R 0 /var/log/httpd /var/run/httpd /etc/httpd && \
    chmod -R g=u /var/log/httpd /var/run/httpd /etc/httpd

COPY src/ ${DOCROOT}/
    
USER 1001

CMD ["/usr/sbin/httpd","-DFOREGROUND"]
