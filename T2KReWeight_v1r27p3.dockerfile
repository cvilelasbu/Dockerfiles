FROM centos:7.2.1511
# Tools needed for installation (to be removed at the end)
RUN yum install -y wget 
RUN yum install -y gcc 
RUN yum install -y gcc-c++ 
RUN yum install -y gcc-gfortran 
RUN yum install -y make 
RUN yum install -y imake 
RUN yum install -y tcsh 
RUN yum install -y ed 
RUN yum install -y file
RUN yum install -y svn
RUN yum install -y byacc
RUN yum install -y byaccj
RUN yum install -y binutils
RUN yum install -y flex
RUN yum install -y unzip

# Remove aliases that will hold up the CERNLIB installation scripts
#RUN unalias cp mv rm 
RUN sed -i 's:alias:#alias:g' ~/.bashrc 
RUN sed -i 's:alias:#alias:g' ~/.tcshrc 
RUN sed -i 's:alias:#alias:g' ~/.cshrc

# Libraries that we will need
RUN yum install -y libXt-devel
RUN yum install -y libXft-devel 
RUN yum install -y libXpm-devel
RUN yum install -y libXext-devel
RUN yum install -y openmotif-devel
RUN yum install -y fftw-devel
RUN yum install -y flex-devel
RUN yum install -y gmp-devel

# Install CERNLIB
RUN mkdir -p /opt/CERNLIB
WORKDIR /opt/CERNLIB
RUN wget http://www-zeuthen.desy.de/linear_collider/cernlib/new/cernlib-2005-all-new.tgz
RUN wget http://www-zeuthen.desy.de/linear_collider/cernlib/new/cernlib.2005.corr.2014.04.17.tgz
RUN wget http://www-zeuthen.desy.de/linear_collider/cernlib/new/cernlib.2005.install.2014.04.17.tgz
RUN tar xfvz cernlib-2005-all-new.tgz
RUN mv -f cernlib.2005.corr.2014.04.17.tgz cernlib.2005.corr.tgz
RUN tar xfvz cernlib.2005.install.2014.04.17.tgz
RUN ls \
    && pwd \
    && ls cernlib_env \
    && source ${PWD}/cernlib_env \
    && ./Install_cernlib_and_lapack

RUN mkdir -p /opt/ROOT
WORKDIR /opt/ROOT
RUN wget https://root.cern.ch/download/root_v5.34.36.source.tar.gz
RUN tar xfz root_v5.34.36.source.tar.gz
RUN rm root_v5.34.36.source.tar.gz
WORKDIR /opt/ROOT/root
RUN ./configure --enable-unuran --enable-roofit --enable-gdml --enable-minuit2 --enable-fftw3 --with-f77=gfortran\
    && make

WORKDIR /

# Get NEUT
RUN mkdir -p /opt/NEUT/
WORKDIR /opt/NEUT/
# From https://www.t2k.org/asg/xsec/niwgdocs/neut/neut_5.3.3_maqefix_t2krw_v1r27p3.tar.gz
ADD neut_5.3.3_maqefix_t2krw_v1r27p3.tar.gz /opt/NEUT/

# Set up environment
ENV NEUT_ROOT  /opt/NEUT/
ENV LD_LIBRARY_PATH ${SKOFL_ROOT}/lib:${ROOTSYS}/lib:$LD_LIBRARY_PATH

# Install NEUT libraries
WORKDIR /opt/NEUT/src/neutsmpl

RUN source /opt/ROOT/root/bin/thisroot.sh \
    && cd /opt/CERNLIB/ \             
    && source /opt/CERNLIB/cernlib_env \
    && cd - \
    && sed -i 's:#setenv FC gfortran:setenv FC gfortran:g' EnvMakeneutsmpl.csh \
    && sed -i 's:#setenv CERN .*:setenv CERN '${CERN}':g' EnvMakeneutsmpl.csh  \
    && sed -i 's:#setenv CERN_LEVEL .*:setenv CERN_LEVEL '${CERN_LEVEL}':g' EnvMakeneutsmpl.csh  \
    && sed -i 's:#setenv ROOTSYS .*:setenv ROOTSYS '${ROOTSYS}':g' EnvMakeneutsmpl.csh  \
    && ./Makeneutsmpl.csh

RUN mkdir -p /opt/GEANTReWeight/
ADD GEANTReWeight_v1r1.tar.gz /opt/GEANTReWeight/

RUN mkdir -p /opt/NIWGReWeight/
ADD NIWGReWeight_v1r23p2.tar.gz /opt/NIWGReWeight/

RUN mkdir -p /opt/JReWeight/
ADD JReWeight_v1r13.tar.gz /opt/JReWeight/

RUN mkdir -p /opt/T2KReWeight/
ADD T2KReWeight_v1r27p3.tar.gz /opt/T2KReWeight/

RUN mkdir /opt/libReadoaAnalysis
WORKDIR /opt/libReadoaAnalysis

COPY oa_nt_beam_90410000-0000_sot7hsri7hfb_anal_001_prod6amagnet201011waterc-bsdv01_2.root /opt/

# Build libReadoaAnalysis
RUN echo 'void tempScript(){' > tempScript.C \
    && echo 'TFile * f = new TFile("/opt/oa_nt_beam_90410000-0000_sot7hsri7hfb_anal_001_prod6amagnet201011waterc-bsdv01_2.root");' >> tempScript.C \
    && echo 'f->MakeProject("libReadoaAnalysis","*","recreate++");' >> tempScript.C \
    && echo '}' >> tempScript.C \       
    && cat tempScript.C \
    && source /opt/ROOT/root/bin/thisroot.sh \
    && root -b -q tempScript.C \
    && rm tempScript.C


# Build GEANTReWeight
WORKDIR /opt/GEANTReWeight/GEANTReWeight/
RUN source /opt/ROOT/root/bin/thisroot.sh \
    && make all

# Build NIWGReWeight
WORKDIR /opt/NIWGReWeight/NIWGReWeight
RUN source /opt/ROOT/root/bin/thisroot.sh \
    && make all

# Build JReWeight
WORKDIR /opt/JReWeight/JReWeight
RUN source /opt/ROOT/root/bin/thisroot.sh \
    && make all

# Write setup script
RUN echo '#!/bin/bash' > /opt/setup.sh \
    && echo 'source /opt/ROOT/root/bin/thisroot.sh' >> /opt/setup.sh \
    && echo 'export T2KREWEIGHT=/opt/T2KReWeight/T2KReWeight/ '  >> /opt/setup.sh \
    && echo 'export PATH=$T2KREWEIGHT/bin:$PATH:$T2KREWEIGHT/app:$ROOTSYS/bin:$PATH' >> /opt/setup.sh \
    && echo 'export LD_LIBRARY_PATH=$T2KREWEIGHT/lib:$LD_LIBRARY_PATH'  >> /opt/setup.sh \
    && echo 'export OAANALYSISLIBS=/opt/libReadoaAnalysis/libReadoaAnalysis'  >> /opt/setup.sh \
    && echo 'export LD_LIBRARY_PATH=$OAANALYSISLIBS:$LD_LIBRARY_PATH' >> /opt/setup.sh \
    && echo 'cd /opt/CERNLIB/'   >> /opt/setup.sh \
    && echo 'source /opt/CERNLIB/cernlib_env'  >> /opt/setup.sh \
    && echo 'cd -'   >> /opt/setup.sh \
    && echo 'export NEUT_ROOT=/opt/NEUT/'  >> /opt/setup.sh \
    && echo 'export PATH=$NEUT_ROOT/src/neutsmpl/bin:$PATH' >> /opt/setup.sh \
    && echo 'export LD_LIBRARY_PATH=$NEUT_ROOT/src/reweight:$LD_LIBRARY_PATH' >> /opt/setup.sh \
    && echo 'export JNUBEAM=/opt/JReWeight/JReWeight'  >> /opt/setup.sh \
    && echo 'export LD_LIBRARY_PATH=${JNUBEAM}:$LD_LIBRARY_PATH' >> /opt/setup.sh \
    && echo 'export JREWEIGHT_INPUTS=${JNUBEAM}/inputs' >> /opt/setup.sh \
    && echo 'export NIWG=/opt/NIWGReWeight/NIWGReWeight' >> /opt/setup.sh \
    && echo 'export LD_LIBRARY_PATH=${NIWG}:$LD_LIBRARY_PATH' >> /opt/setup.sh \
    && echo 'export NIWGREWEIGHT_INPUTS=${NIWG}/inputs' >> /opt/setup.sh \
    && echo 'export GEANTRW=/opt/GEANTReWeight/GEANTReWeight'>> /opt/setup.sh \
    && echo 'export LD_LIBRARY_PATH=${GEANTRW}:$LD_LIBRARY_PATH'>> /opt/setup.sh \
    && echo 'export GEANTREWEIGHT_INPUTS=${GEANTRW}/inputs'>> /opt/setup.sh


# Get rid of psyche-ish apps (for now)

Run sed -i 's/all: genWeightsFromNRooTracker_BANFF_2016 genWeightsSKsplines_NIWG.exe genWeightsSKsplines_NIWG_BeRPA.exe genWeightsFromNRooTracker_ND280_NIWG_Validation/all: /g' /opt/T2KReWeight/T2KReWeight/app/Makefile
WORKDIR /opt/T2KReWeight/T2KReWeight

# Configure and build T2KReWeight
RUN source /opt/setup.sh \
    && ./configure --enable-neut --enable-jnubeam --enable-oaanalysis --enable-niwg --enable-geant --disable-psyche --with-oaanalysis-lib=/opt/libReadoaAnalysis/libReadoaAnalysis/ --with-cern=${CERN_ROOT} \
    && make

# Remove build tools
RUN yum -y remove wget 
RUN yum -y remove gcc 
RUN yum -y remove gcc-c++ 
RUN yum -y remove gcc-gfortran 
RUN yum -y remove make 
RUN yum -y remove imake 
RUN yum -y remove tcsh 
RUN yum -y remove ed 
RUN yum -y remove file
RUN yum -y remove svn
RUN yum -y remove byacc
RUN yum -y remove byaccj
RUN yum -y remove flex
RUN yum -y remove unzip

# Restore CentOS default aliases
RUN alias cp="cp -i" mv="mv -i" rm="rm -i" 
RUN sed -i 's:#alias:alias:g' ~/.bashrc \
    && sed -i 's:#alias:alias:g' ~/.tcshrc \
&& sed -i 's:#alias:alias:g' ~/.cshrc
