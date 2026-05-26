# docker-dev-framework
A flexible and configurable docker-based development framework for working on various projects

1) Quick Start
2) Conceptual Model
3) Customization
4) Advanced mechanics / Reference

## 1. Overview
What DDF is:
- Multi-stage Docker-based development framework
- Project-driven customization
- Supports customization by project-driven build hooks
- Intended for reproducible development environments
- Supports (TBD) a production container as well
- Supports (among other things):
  - ROS2
  - GUI applications
  - Multiple languages, including Python, C++, C#, NodeJS, etc.
  - Cached vendor SDKs
  - Multi-project workspaces
  - Any Linux flavor

Design Goals:
- Reproducible
- Composable
- Project-owned customization
- Host-independent
- Layered/staged builds
- No framework modification per project (or minimal, at least)

DDF is intended to be a flexible environment that can be used as a development environment on any system that can support Docker. It's been used, in various incarnations, on Ubuntu and Windows/WSL2, but should also work on macOS.

An important advantage to a container-based IDE is that all the customization to support the development environment goes inside the container. You're not plugging all sorts of random stuff into your host operating system, potentally installing incompatible versions and having to carefully manage the configuration. Instead, the installed packages and verions are easily managed via the DDF Dockerfile and the project customization hooks.

The basic idea is the container can be customized (via customization hooks in the project workspaces, thus not requireing DDF modification for each project) to build in whatever required resources the project needs. It can (will) support the building of two different containers: an interactive development container, and a turnkey production container suitable for depooyment to a VM or the cloud.

The interactive development container supports GUI applications. I've used VS Code inside the ontainer in the past, but now it seems VS Code with the Microsoft Dev Containers extension.

## 2. Quick Start

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
There are two files to configure here: project.env and workspace_dirs.bash.
#### project.env
There are four variables to configure here: *asdf* 

- PROJECT= _the project name, will be used to build the container name_.
- ORGANIZATION= _also used in the container name_.
- SERVER_USER= _used as the username inside the dev container_.
- DOCKER_ROOT_IMAGE= _The docker image to use as the starting point_.

#### workspace_dirs.bash
This file contains the list of project directories to be mounted into the container. An example workspace_dirs.bash might be:
```
WORKSPACE_DIRS=(
    ${HOME}/dev/emulate/jetson_provisioning/ava_setup
)
```
This mounts a single directory, ava_setup, to the docker. It will be mounted to /workspace/ava_setup. You can list as many directories as you like, each on a separate line with no commas or other punctuation between them. Be careful not to try to mount two directories with identical names; DDF isn't smart enough to handle that.

### Build the container

```
$ make
```

### Enter the container
```
$ ddf shell
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
