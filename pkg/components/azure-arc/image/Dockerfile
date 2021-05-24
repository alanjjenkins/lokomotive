FROM mcr.microsoft.com/azure-cli

ARG VERSION

# ENV BASE_URL="https://storage.googleapis.com/kubernetes-helm"
ENV BASE_URL="https://get.helm.sh"
ENV TAR_FILE="helm-v${VERSION}-linux-amd64.tar.gz"


RUN apk add --update --no-cache curl ca-certificates && \
    curl -L ${BASE_URL}/${TAR_FILE} |tar xvz && \
    mv linux-amd64/helm /usr/bin/helm && \
    chmod +x /usr/bin/helm && \
    rm -rf linux-amd64 && \
    apk del curl && \
    rm -f /var/cache/apk/*

RUN az extension add --name connectedk8s

WORKDIR /azure-arc

COPY script.sh /azure-arc/script.sh
RUN chmod +x /azure-arc/script.sh
#ENTRYPOINT ["/azure-arc/script.sh"]
