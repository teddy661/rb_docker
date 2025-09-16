##
## Production Image Below
ARG PY_VERSION=3.13.7
ARG PY_THREE_DIGIT=313
ARG PY_SHORT=3.13
ARG XGB_VERSION=3.0.5

FROM ebrown/python:${PY_VERSION} AS built_python
FROM ebrown/git:latest AS built_git
# FROM nvidia/cuda:12.4.1-cudnn-devel-rockylinux9 AS base
FROM nvidia/cuda:12.9.1-cudnn-runtime-rockylinux9 AS base
SHELL ["/bin/bash", "-c"]

ARG PY_VERSION=3.13.7
ARG PY_THREE_DIGIT=313
ARG PY_SHORT=3.13
ARG XGB_VERSION=3.0.5
ARG INSTALL_NODE_VERSION=22.19.0
ARG INSTALL_NUMPY_VERSION=2.3.3
ARG INSTALL_SCIPY_VERSION=1.16.2
## 
## TensorRT drags in a bunch of dependencies that we don't need
## tried replacing it with lean runtime, but that didn't work
## The below code appears to resolve that issue.
##
RUN yum install dnf-plugins-core -y && \
    dnf install epel-release -y && \
    /usr/bin/crb enable -y && \
    dnf --disablerepo=cuda update -y && \
    dnf install \
                unzip \
                wget \
                libcurl-devel \
                gettext-devel \
                expat-devel \
                openssl-devel \
                openssh-server \
                openssh-clients \
                bzip2-devel bzip2 \
                xz-devel xz \
                libffi-devel \
                zlib-devel \
                ncurses ncurses-devel \
                readline-devel \
                libgfortran \
                uuid uuid-devel \
                tcl-devel tcl\
                tk-devel tk\
                sqlite-devel \
                graphviz \
                gdbm-devel gdbm \
                procps-ng \
                findutils -y && \
                dnf clean all;
RUN mkdir /opt/nodejs && \
    cd /opt/nodejs && \
    curl -L https://nodejs.org/dist/v${INSTALL_NODE_VERSION}/node-v${INSTALL_NODE_VERSION}-linux-x64.tar.xz | xzcat | tar -xf - && \
        PATH=/opt/nodejs/node-v${INSTALL_NODE_VERSION}-linux-x64/bin:${PATH} && \
        npm install -g npm && npm install -g yarn
RUN mkdir /opt/nvim && \
    cd /opt/nvim && \
    curl -L https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz | tar -zxf -
ENV PATH=/opt/nodejs/node-v${INSTALL_NODE_VERSION}-linux-x64/bin:/opt/nvim/nvim-linux64/bin:${PATH}
RUN ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa \
    && ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa \
    && ssh-keygen -f /etc/ssh/ssh_host_ecdsa_key -N '' -t ecdsa -b 521 \
    && ssh-keygen -f /etc/ssh/ssh_host_ed25519_key -N '' -t ed25519
COPY --from=built_python /opt/python/py${PY_THREE_DIGIT} /opt/python/py${PY_THREE_DIGIT}
COPY --from=built_git /opt/git /opt/git
ENV LD_LIBRARY_PATH=/opt/python/py${PY_THREE_DIGIT}/lib:${LD_LIBRARY_PATH}
ENV PATH=/opt/git/bin:/opt/python/py${PY_THREE_DIGIT}/bin:${PATH}
ENV PYDEVD_DISABLE_FILE_VALIDATION=1
WORKDIR /tmp
COPY installmkl.sh ./installmkl.sh
COPY --from=ebrown/xgboost:latest /tmp/bxgboost/xgboost/python-package/xgboost-${XGB_VERSION}-py3-none-manylinux_2_34_x86_64.whl ./xgboost-${XGB_VERSION}-py3-none-manylinux_2_34_x86_64.whl
COPY --from=ebrown/mkl-numpy-scipy:latest /tmp/numpy/numpy/dist/numpy-${INSTALL_NUMPY_VERSION}-cp${PY_THREE_DIGIT}-cp${PY_THREE_DIGIT}-linux_x86_64.whl ./numpy-${INSTALL_NUMPY_VERSION}-cp${PY_THREE_DIGIT}-cp${PY_THREE_DIGIT}-linux_x86_64.whl
COPY --from=ebrown/mkl-numpy-scipy:latest /tmp/scipy/scipy/dist/scipy-${INSTALL_SCIPY_VERSION}-cp${PY_THREE_DIGIT}-cp${PY_THREE_DIGIT}-linux_x86_64.whl ./scipy-${INSTALL_SCIPY_VERSION}-cp${PY_THREE_DIGIT}-cp${PY_THREE_DIGIT}-linux_x86_64.whl
RUN ./installmkl.sh
RUN pip3 install --no-cache-dir /tmp/numpy-${INSTALL_NUMPY_VERSION}-cp${PY_THREE_DIGIT}-cp${PY_THREE_DIGIT}-linux_x86_64.whl /tmp/scipy-${INSTALL_SCIPY_VERSION}-cp${PY_THREE_DIGIT}-cp${PY_THREE_DIGIT}-linux_x86_64.whl /tmp/xgboost-${XGB_VERSION}-py3-none-manylinux_2_34_x86_64.whl
RUN pip3 install --no-cache-dir \
                torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu129
RUN pip3 install --no-cache-dir \
                ipython \
                bokeh \
                seaborn \
                aiohttp[speedups] \
                "jupyterlab" \
                jupyterlab-server \
                jupyterlab-pygments \
                jupyterlab-theme \
                jupyterlab-lsp \
                jupyter-lsp \
                black[jupyter] \
                matplotlib \
                blake3 \
                papermill[all] \
                statsmodels \
                psutil \
                mypy \
                # "pandas[performance, excel, computation, plot, output_formatting, html, parquet, hdf5]" \
                # Remove performance since that includes numba which downgrades numpy
                "polars[async,deltalake,excel,fsspec,graph,numpy,pandas,plot,pyarrow,pydantic,style,timezone]" \
                apsw \
                pydot \
                plotly \
                pydot-ng \
                pydotplus \
                graphviz \
                beautifulsoup4 \
                scikit-learn-intelex \
                scikit-learn \
                scikit-image \
                sklearn-pandas \
                lxml \
                isort \
                ipyparallel \
                ipywidgets \
                nbconvert \
                itables \
                jupyter_bokeh \
                jupyter-server-proxy \
                jupyter_http_over_ws \
                jupyter-collaboration \
                ipyparallel \
                pyyaml \
                yapf \
                nbqa[toolchain] \
                ruff \
                pipdeptree \
                bottleneck \ 
                pytest 

WORKDIR /root
COPY ./root/ /root/
COPY entrypoint.sh /usr/local/bin
RUN chmod 755 /usr/local/bin/entrypoint.sh
ENV TERM=xterm-256color
ENV SHELL=/bin/bash
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash", "-c", "jupyter lab"]
