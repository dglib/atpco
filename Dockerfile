FROM  registry.redhat.io/rhel7-atomic:7.4-131


MAINTAINER Veerendra K Akula <vakula@atpco.net>

ENV JAVA_HOME="/usr/lib/jvm/jre-1.8.0" \
    JAVA_VENDOR="openjdk" \
    JAVA_VERSION="1.8-171" \
    PATH=$PATH:"/usr/local/s2i" \   
    JAVA_DATA_DIR=/deployments/data
	
ENV TZ=America/New_York

# version information
LABEL io.k8s.description="Platform for running plain Java applications" \
      io.k8s.display-name="Java Applications" \
      io.openshift.tags="builder,java" \
      io.openshift.s2i.scripts-url="image:///usr/local/s2i" \
      io.openshift.s2i.destination="/tmp" \
      io.openshift.expose-services="8080" \
      org.jboss.deployments-dir="/deployments"

  
	  
USER root
RUN microdnf --nodocs --enablerepo=rhel-7-server-rpms  install java-1.8.0-openjdk wget rsync which tar unzip \
    && microdnf clean all \
    && groupadd -r java -g 1000 \
    && useradd -u 2222 -r -g root -m -d /opt/java -s /sbin/nologin -c "Java user" java \
    && usermod -a -G java java \
    && rm -f /etc/localtime \
    && ln -s /usr/share/zoneinfo/$TZ /etc/localtime 

RUN mkdir -p /deployments/data \
   && chmod -R "g+rwX" /deployments \
   && chown -R java:root /deployments

USER 2222

WORKDIR /opt/java

#Expose Ports
EXPOSE 8080
