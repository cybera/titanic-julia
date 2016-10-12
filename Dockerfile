# Julia w/ precompiled packages

FROM julialang/julia:v0.5.0

MAINTAINER Cybera

ADD scripts/_install.jl /tmp/_install.jl
RUN /opt/julia/bin/julia --load /tmp/_install.jl

#ENTRYPOINT /bin/bash