# docker-dev-framework
A flexible and configurable docker-based development framework for working on various projects

1. Overview
2. Glossary
3. Installation and Configuration
3. Concepts
3) Customization
5. Reference
6. Troubleshooting
7. Examples
8. Philosophy

## 1. Overview
### What DDF is:
The Docker Development Framework (DDF) is a multi-stage Docker-based framework for creating reproducible, project-specific development environments. Rather than requiring each project to maintain its own Dockerfile, DDF allows projects to customize shared development images through build hooks and other metadata, while keeping the framework itself generic.

Although DDF currently focuses on building an interactive development environment, its staged architecture was conceived in part to support the generation of lean production images suitable for deployment (to VMs, like AWS or GCP, or to frameworks like Kubernetes).

DDF has successfully been used for projects involving:
- ROS2
- GUI applications
- Multiple languages, including Python, C++, C#, and NodeJS
- Cached vendor SDKs
- Multi-repo workspaces
- Different flavors of Linux

Docker does not, by default, support running GUI applications from insde the container, but this has been supported by DDF. You can even run a GUI-based IDE inside the DDF container, although with VS Code, it's easier to run it outside.

### Why DDF exists:
DDF solves a few different problems involved in application development:

**Isolation of host machine issues**<br>
It allows a project's development environment to be managed without significantly affecting the host machine. It eliminates incompatibilities between the requirements of different projects that many need to be developed on the same host machine. Often the trial and error approach to installing packages leaves a host machine's OS full of weird and potentially damaging artifacts. Docker separates its internal configuration from the host operating system.

**Projects own their customizations**<br>
Projects have all sorts of requirements, whether its runtime shared objects, development frameworks, or resources. By tying these to the projects, it allows everything to move with the project, rather than requiring every new host machine to discover and install the requirements. It reduces the need for long elaborate "setting up the dev environment" documents that new employees all have to suffer through.

**Allows for a quick start for new developers**<br>
By encapsulating the configuration and support data in the project, a new developer doesn't have to grapple with it at first. It allows someone without deep knowledge of an application to start developing without having to delve into the issues of configuring an environment to build and run it.

### Design Goals:
DDF was explicitly intended to be:
- Reproducible: by capturing most configuration in the Dockerfile and shell scripts, the environment can be dependably rebuilt.
- Composable: Leveraging the strength of Docker-based environments, it allows the environment to be considered and designed consciously, not evolved by trial-and-error.
- Customizable: A lot of little tweaks are possible using the build hooks that DDF provides. And since the customization is in metadata attached to the projects, primarily in the form of build hook scripts and configuration files, it's clearer and more intuitive.
- Host independent: While any Docker environment isn't completely separated from concerns about the host, and its kernel, a lot of DDF is not dependent on the host. Most projects should run basically the same on different hosts.
- Layered: the staged builds allow clearer separation of considerations and issues when designing the build hooks and planning the environment.
- Project-owned: DDF exists to build a customized development environment for any project, using the metadata in the project. The configuration is owned by the projects, and checked in with them, not with DDF.

DDF very consciously and deliberately separates the generic framework and the management of DDF containers from the project-specific customizations. The DDF framework can be tied to innumerable projects, and ideally a project can even be moved from one DDF framework to another, carrying its customizations with it.

While DDF is compatible with Windows/WSL2, and has been used there, it is not currently being actively developed or tested there.

## 2. Glossary
Terms and concepts in this space:
| Term | Definition |
|------|------------|
| Container | The live instance of a Docker image |
| Image | The output of the Docker build operation, it's a potential container. |
| Project | A directory tree containing code that is under development in DDF. Each project can supply its own development hooks to customize the built Docker image. |
| Workspace | The docker framework, potentially containing one or more projects. Except for the local workspace-config data, this should usually be an unaltered copy of the DDF repo. |
| Stage | ... |
| Hook | ... |



## 3. Installation and Configuration

DDF can be used with minimal customization.

### Prerequisites

- Docker - BuildKit enabled version
- Make
- Git

### Clone the framework:
```
git clone git@github.com:BobPitha/docker-dev-framework.git [dirname]
```

### Configure workspace-config files
There are two files to configure here: workspace.env and project_dirs.bash.
#### workspace.env
There are four variables to configure here: *asdf* 

- PROJECT= _the project name, will be used to build the container name_.
- ORGANIZATION= _also used in the container name_.
- SERVER_USER= _used as the username inside the dev container_.
- DOCKER_ROOT_IMAGE= _The docker image to use as the starting point_.

#### project_dirs.bash
This file contains the list of project directories to be mounted into the container. An example project_dirs.bash might be:
```
PROJECT_DIRS=(
    ${HOME}/dev/foo
)
```
This mounts a single directory, foo, to the docker. It will be mounted to /projects/ava_setup. You can list as many directories as you like, each on a separate line with no commas or other punctuation between them. Be careful not to try to mount two directories with identical names; DDF isn't smart enough to handle that.

#### Make the ddf script executable (optional but recommended)
There are some ddf commands (ddf shell, ddf stop, ddf clean, ddf clean-all) that use the ddf helper script. To avoid having to type a path to the ddf script in the ddf repo's bin directory, you can copy the script to a directory in your path.

### Build the container

```
$ make
```

### Enter the container
```
$ ddf shell
bob@ddf-dev:~$
```

## 3. Core Concepts
### Multi-Stage Build
The container is built in multiple stages:
- base: Basic OS, runtime. Configuration shared by dev and prod containers
- dev-core: Core develop components, basics of the interactive shell
- dev-tooling: SDKs, toolchains.
- dev-gui: GUI components and resources, graphical apps, support for front ends
- prod: runtime-only non-interactive deployable container

## 4. Project Customization
In each project directory, there can be the following folder structure:
```
.ddf/
  build/
    base/
    dev-core/
    dev-tooling/
    dev-gui/
    prod/
```
During the container build, customization hook scripts will be gathered into a folder structure in the DDF directory:
```
.generated/
  ddf-build-hooks/
  ddf-libs/
```

## 5. Build Hooks
Build hooks are small (usually) shell scripts that are invoked from the Dockerfile build at the end of each build stage, to customize that stage for each attached repo. If one project needs python resources to support a python application, they might be installed in dev-tooling. ROS might be mostly installed in base, although runtime GUI apps like foxglove or rviz would be installed in dev-gui.

build hooks for a particular stage can be (using base as an exmple):
```
.ddf/build/base.sh
.ddf/build/base/*.sh
```
.ddf/build/base.sh will be invoked first, then the rest in lexical order. I recommend prefixing the hook scripts with an integer to force the order: 10-foo.sh, for instance. 

During the build, the hooks will be gathered into the .generated/ddf-build-hooks/<stage> directories and executed from there.

### Hook Script Environment

### Hook Best Practices

## 6. Cached Binary Artifacts
### Motivation
### Host Cache
### Generated Staging Directory
### BuildKit Mount
### Typical Flow
### Example SDK Hooks

## 7. Host-Side Configuration
### Shared Cache Variable

## 8. Makefile Targets
### Common Targets
### Build Options
#### Disable Docker Cache
#### Plain Build Output
#### Build Logging

## 9. Python Environment Support
### Recommended Pattern
### Example Hooks

## 10. Shell Customization
### Interactive Bash Integration
### Recommended Uses

## 11. ROS2 Support
### ROS Distro Selection
### Recommended Build Workflow
### rosdep Notes

## 12. GUI Support
### X11/Wayland Notes
### Common Runtime Libraries

## 13. Troubleshooting
### Hook Not Running
### BuildKit Problems
### Missing Shared Libraries
### ROS CMake Package Errors
### Broken colcon Install Trees

## 14. Advanced
### Adding New Stages
### Internal Script Architecture

## 15. Exmaple Projects
### ROS2 + Pylon
### Python + Flet
### Native C++ SDK

## 16. Philosophy

## 17. Future Improvemens

## 18. License

## 19. Contributing
