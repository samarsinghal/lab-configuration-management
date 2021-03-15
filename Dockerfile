FROM quay.io/eduk8s/base-environment:master

#conftest 
COPY --from=instrumenta/conftest /conftest /usr/local/bin/conftest
# All the direct Downloads need to run as root as  they are going to /usr/local/bin
USER root

# ENV ISTIO_VERSION=1.7.4



# # TMC
# RUN curl -L -o /usr/local/bin/tmc $(curl -s https://tanzupaorg.tmc.cloud.vmware.com/v1alpha/system/binaries | jq -r 'getpath(["versions",.latestVersion]).linuxX64') && \
#   chmod 755 /usr/local/bin/tmc

# # Policy Tools
# RUN curl -L -o /usr/local/bin/opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64 && \
#   chmod 755 /usr/local/bin/opa

# # Velero
# RUN VELERO_DOWNLOAD_URL=$(curl -s https://api.github.com/repos/vmware-tanzu/velero/releases/latest | jq -r '.assets[] | select ( .name | contains("linux-amd64") ) .browser_download_url') && \
#   curl -fL --output /tmp/velero.tar.gz ${VELERO_DOWNLOAD_URL} && \
#   tar -xzf /tmp/velero.tar.gz -C /usr/local/bin --strip-components=1 --wildcards velero-*-linux-amd64/velero && \
#   rm /tmp/velero.tar.gz

# # TAC
# RUN curl -fL --output /tmp/tac.tar.gz https://downloads.bitnami.com/tac/tac-cli_beta-e936104-linux_amd64.tar.gz && \
#   tar -xzf /tmp/tac.tar.gz -C /usr/local/bin tac && \
#   rm /tmp/tac.tar.gz

# # Install System libraries
# RUN echo "Installing System Libraries" \
#   && apt-get update \
#   && apt-get install -y build-essential python3.6 python3-pip python3-dev groff bash-completion git curl unzip wget findutils jq vim tree docker.io

# # Install AWS CLI
# RUN echo "Installing AWS CLI" \
#     && pip3 install --upgrade awscli

# #Install Kustomize
# RUN echo "Installing Kustomize" \
#   && curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash \
#   && mv kustomize /usr/local/bin/kustomize \
#   && kustomize version

# # Install Helm3
# RUN echo "Installing Helm3" \
#   && curl https://get.helm.sh/helm-v3.3.0-rc.2-linux-amd64.tar.gz --output helm.tar.gz \
#   && tar -zxvf helm.tar.gz \
#   && mv linux-amd64/helm /usr/local/bin/helm \
#   && chmod +x /usr/local/bin/helm \
#   && helm version

# # TBS
# # TODO :  Change the logic to identify the latest anbd download  or move to pivnet 
# RUN curl -L -o /usr/local/bin/kp  https://github.com/vmware-tanzu/kpack-cli/releases/download/v0.1.3/kp-linux-0.1.3  && \
#   chmod 755 /usr/local/bin/kp
# RUN curl -sSL "https://github.com/buildpacks/pack/releases/download/v0.14.2/pack-v0.14.2-linux.tgz" | sudo tar -C /usr/local/bin/ --no-same-owner -xzv pack
# RUN curl -sSL "https://github.com/concourse/concourse/releases/download/v6.7.1/fly-6.7.1-linux-amd64.tgz" |sudo tar -C /usr/local/bin/ --no-same-owner -xzv fly

# # Install Carvel tools
# RUN echo "Installing K14s Carvel tools" \
#   && wget -O- https://k14s.io/install.sh | bash 

# # Install Istioctl
# RUN echo "Installing Istioctl" \
#   && curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${ISTIO_VERSION} TARGET_ARCH=x86_64 sh - \
#   && cd istio-${ISTIO_VERSION} \
#   && cp $PWD/bin/istioctl /usr/local/bin/istioctl \
#   && istioctl version

# CONFTEST
# RUN echo "Installing Conftest" \
#   && curl https://github.com/open-policy-agent/conftest/releases/download/v0.21.0/conftest_0.21.0_Linux_x86_64.tar.gz --output conftest \
#   && tar -xzf conftest
#   # && mv conftest /usr/local/bin \
#   # && chmod +x /usr/local/bin/conftest


RUN curl -fL https://github.com/open-policy-agent/conftest/releases/download/v0.21.0/conftest_0.21.0_Linux_x86_64.tar.gz --output conftest.tar.gz \
    && tar -xzf conftest.tar.gz -C /usr/local/bin conftest \
    && rm conftest.tar.gz

RUN curl -L https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.15.0/kubeseal-linux-amd64 --output kubeseal \
    && install -m 755 kubeseal /usr/local/bin/kubeseal

USER 1001

COPY --chown=1001:0 . /home/eduk8s/

RUN mv /home/eduk8s/workshop /opt/workshopd

RUN fix-permissions /home/eduk8s

# ENTRYPOINT ["tail", "-f", "/dev/null"]