local distro = "opensuse-tumbleweed";
local distro_name = 'OpenSUSE Tumbleweed';
local distro_docker = 'opensuse/tumbleweed';

local submodules = {
    name: 'submodules',
    image: 'drone/git',
    commands: ['git fetch --tags', 'git submodule update --init --recursive']
};

local zypper(arch) = 'zypper -n --cache-dir /cache/'+distro+'/'+arch+'/${DRONE_STAGE_MACHINE} ';

local rpm_pipeline(image, buildarch='amd64', rpmarch='x86_64', jobs=6) = {
    kind: 'pipeline',
    type: 'docker',
    name: distro_name + ' (' + rpmarch + ')',
    platform: { arch: buildarch },
    steps: [
        submodules,
        {
            name: 'build',
            image: image,
            environment: {
                SSH_KEY: { from_secret: "SSH_KEY" },
                RPM_BUILD_NCPUS: jobs
            },
            commands: [
                'echo "Building on ${DRONE_STAGE_MACHINE}"',
                zypper(rpmarch) + 'up',
                zypper(rpmarch) + 'install rpm-build python3-pip ccache git',
                'pip3 install git-archive-all',
                'pkg_src_base="$(rpm -q --queryformat=\'%{NAME}-%{VERSION}\n\' --specfile SPECS/oxenmq.spec | head -n 1)"',
                'git-archive-all --prefix $pkg_src_base/ SOURCES/$pkg_src_base.src.tar.gz',
                zypper(rpmarch) + '-n install $(rpmspec --parse SPECS/oxenmq.spec | grep BuildRequires | sed -e "s/^BuildRequires: *//")',
                'if [ -n "$CCACHE_DIR" ]; then mkdir -pv ~/.cache; ln -sv "$CCACHE_DIR" ~/.cache/ccache; fi',
                'rpmbuild --define "_topdir $(pwd)" -bb SPECS/oxenmq.spec',
                './SPECS/ci-upload.sh ' + distro + ' ' + rpmarch,
            ],
        }
    ]
};

[
    rpm_pipeline(distro_docker),
    // rpm_pipeline("arm64v8/" + distro_docker, buildarch='arm64', rpmarch="aarch64", jobs=4)
]
