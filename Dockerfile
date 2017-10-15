FROM ubuntu:trusty

RUN apt-get update
RUN apt-get install -y software-properties-common jq

RUN add-apt-repository ppa:ethereum/ethereum
RUN apt-get update
RUN apt-get install -y geth bootnode
