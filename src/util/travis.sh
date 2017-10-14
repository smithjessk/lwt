set -x



# Install system packages.
packages_apt () {
    case $COMPILER in
        4.01) PPA=avsm/ocaml41+opam12;;
        4.02) PPA=avsm/ocaml42+opam12;;
        4.03) PPA=avsm/ocaml42+opam12; DO_SWITCH=yes;;
        4.04) PPA=avsm/ocaml42+opam12; DO_SWITCH=yes;;
        4.05) PPA=avsm/ocaml42+opam12; DO_SWITCH=yes;;
        4.06) PPA=avsm/ocaml42+opam12; DO_SWITCH=yes; HAVE_CAMLP4=no;;
           *) echo Unsupported compiler $COMPILER; exit 1;;
    esac

    sudo add-apt-repository -y ppa:$PPA
    sudo apt-get update -qq

    if [ -z "$DO_SWITCH" ]
    then
        sudo apt-get install -qq ocaml-nox
    fi

    sudo apt-get install -qq opam

    if [ "$LIBEV" != no ]
    then
        sudo apt-get install -qq libev-dev
    fi
}

packages_homebrew () {
    brew update > /dev/null

    if [ "$COMPILER" = system ]
    then
        brew install ocaml
    else
        DO_SWITCH=yes
    fi

    brew install gtk+ opam

    if [ "$LIBEV" != no ]
    then
        brew install libev
    fi
}

packages_macports () {
    eval `wget -q -O - https://aantron.github.io/binaries/macports/x86_64/macports/current/install.sh | bash`
    sudo port install pkgconfig gtk2 | cat

    if [ "$LIBEV" != no ]
    then
        sudo port install libev | cat
    fi

    wget -q -O - https://aantron.github.io/binaries/macports/x86_64/opam/1.2/install.sh | bash
    wget -q -O - https://aantron.github.io/binaries/macports/x86_64/ocaml/$COMPILER/install.sh | bash
    wget -q -O - https://aantron.github.io/binaries/macports/x86_64/camlp4/$COMPILER/install.sh | bash
}

packages_osx () {
    case $PACKAGE_MANAGER in
        macports) packages_macports;;
               *) packages_homebrew;;
    esac
}

packages () {
    case $TRAVIS_OS_NAME in
        linux) packages_apt;;
          osx) packages_osx;;
            *) echo Unsupported system $TRAVIS_OS_NAME; exit 1;;
    esac
}

packages



# Initialize OPAM and switch to the right compiler, if necessary.
case $COMPILER in
    4.01) OCAML_VERSION=4.01.0;;
    4.02) OCAML_VERSION=4.02.3;;
    4.03) OCAML_VERSION=4.03.0;;
    4.04) OCAML_VERSION=4.04.2;;
    4.05) OCAML_VERSION=4.05.0;;
    4.06) OCAML_VERSION=4.06.0+beta1;;
    system) OCAML_VERSION=`ocamlc -version`;;
       *) echo Unsupported compiler $COMPILER; exit 1;;
esac

if [ "$FLAMBDA" = yes ]
then
    SWITCH="$OCAML_VERSION+flambda"
else
    SWITCH="$OCAML_VERSION"
fi

if [ -n "$DO_SWITCH" ]
then
    opam init --compiler=$SWITCH -ya
else
    opam init -ya
fi

eval `opam config env`

ACTUAL_COMPILER=`ocamlc -version`
if [ "$ACTUAL_COMPILER" != "$OCAML_VERSION" ]
then
    echo Expected OCaml $OCAML_VERSION, but $ACTUAL_COMPILER is installed
fi



# Pin Lwt, and install its dependencies.
opam pin add -y --no-action lwt .
opam install -y --deps-only lwt

if [ "$HAVE_CAMLP4" != no ]
then
    opam install -y camlp4
fi

if [ "$LIBEV" != no ]
then
    opam install -y conf-libev
fi

# Pin additional packages and install their dependencies.

# Install dependencies of extra packages. We don't do this by pinning them and
# using opam install --deps-only, because that will cause package lwt to be
# installed.

opam install -y react ssl conf-glib-2 conf-pkg-config

# Build Lwt and extra packages.
if [ "$LIBEV" != no ]
then
    LIBEV_FLAG=true
else
    LIBEV_FLAG=false
fi

if [ "$HAVE_CAMLP4" = no ]
then
    CAMLP4_FLAG=false
else
    CAMLP4_FLAG=true
fi

ocaml src/util/configure.ml -use-libev $LIBEV_FLAG -use-camlp4 $CAMLP4_FLAG
make build-all

# Run tests.
make test-all

# Clean for installation and packaging tests.
make clean



# Run the packaging tests.
make install-for-packaging-test
make packaging-test



# Some sanity checks.
if [ "$LIBEV" != yes ]
then
    ! opam list -i conf-libev
fi

opam list -i ppx_tools_versioned
! opam list -i batteries
