# docker-dev-framework
A flexible and configurable docker-based development framework for working on various projects

1. Overview
2. Quick Start
3. Conceptual Model

2. Glossary
3. Installation and Configuration
3. Concepts
3) Customization
5. Reference
6. Troubleshooting
7. Examples
8. Philosophy

## 1. Overview
- What DDF Is
- Why DDF Exists
- Design Goals

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

## 2. Quick Start
- Prerequisites
- Downloading
- Configuring
- make
- ddf commands

This section walks you through configuring a DDF workspace, associating it with one or more existing projects, building a development container, and shelling into it.

This section uses examples of a robotic software workspace. Specifically, it assumes:
```
~/dev/robot/
 |
 | ├── motion-control/
 | ├── robot-data/
 | ├── task-planner/
 | └── vision/
 |
 └── robot-ddf/
```
### Prerequisites
To use DDF you need some basic configuration of your system. Specifically, you need:
- Docker - specifically with BuildKit
- ??? I don't know what else off the top of my head.

### Downloading
Clone the DDF repository into the directory that will become the root of your development workspace:
`git clone git@github.com:BobPitha/docker-dev-framework.git robot-ddf`<br>
--or--<br>
`git clone https://github.com/BobPitha/docker-dev-framework.git robot-ddf`

Because you need a separate DDF repo for each DDF workspace you use, consider giving the local DDF clone a name unique to the project but still clearly DDF. Something like robot-ddf.

### Configuring
Inside the cloned DDF directory, you'll find `workspace-config/`, containing two files:
- `project_dirs.bash`
- `workspace.env`

These two files are usually all that has to be modified to link this DDF workspace to its project directories.

#### project_dirs.bash
This file is what links this workspace (robot-ddf) to the project directories. Every directory named here will be scanned for a .ddf directory, which supplies metadata, build hooks, and configuration. Each project directory is also mounted into the workspace container.

Out of the box, this file contains just an empty list. Insert the project directory, or list of directories (one per line, no separators) that the framework will build a container for. So, for example:
```
PROJECT_DIRS=(
  ${HOME}/dev/robot/vision/
  ${HOME}/dev/robot/motion-control/
  ${HOME}/dev/robot/task-planner/
  ${HOME}/dev/robot/robot-data/
)
```
#### workspace.env
This file defines the basic identity of this workspace and the Docker images it produces
. By default, it contains:
```
WORKSPACE_NAME=ddf
ORGANIZATION=bob
SERVER_USER=bob
DOCKER_ROOT_IMAGE=ubuntu:noble

# https://robotmoon.com/256-colors/
HOST_COLOR=207
PATH_COLOR=154
```
**WORKSPACE_NAME**: this is used as the basis for generating container image names, as well as the hostname of the docker. We might choose 'robot' for this example.

**ORGANIZATION**: Is used to label the container, and is accessible inside the build hooks and in the running container as needed.

**SERVER_USER**: is the name of the user (and group) set up inside the docker container. You will be automatically running as this user, and your home is /home/${SERVER_USER}. 

**DOCKER_ROOT_IMAGE**: the Docker image to use as the root of all customizations. By default it's ubuntu:noble (that's 24.04), but can easily be set to something older, newer, or even non-Ubuntu. However, I haven't tested much outside of a few versions older or the newer Ubuntu. You might run into issues, please contact me (rpitha@gmail.com) for help if necessary.

**HOST_COLOR** and **PATH_COLOR**: these are to make the container shell visually distinctive, so you know which shell is in the container and which isn't. Feel free to pick colors you liek from the 256 colors in the linked document/

### make
Once DDF is configured per above, you can generate the Docker image by typing:<br>
`$ make dev`<br>
or even just,<br>
`$ make`
For workspaces with extensive customization (lookin' at you, ROS2!) it can take a while. When it completes successfully, you have a Docker image.

The build process does a number of things:
- collects build hook scripts from the linked projects,
- builds a docker image
- tags it using the workspace name, organization, and current git commit.

### ddf commands
There are a couple commands to control the DDF container:
- `ddf shell`: opens a shell in the container, starting it running if needed.
- `ddf stop`: stops the current running container. There should only be one at any time.

Since `ddf shell` will use the current running container even if a newer one has been built, you should use `ddf stop` if you've just built a new version. If the ddf repo has been updated and is on a new commit SHA, DDF will insist you build a new version of the shell and switch to it.

### Typical workflow
A typical workflow with DDF involves:
1. Configure the workspace (see above)
2. `make` (takes a while, go play in the hallway (https://imgs.xkcd.com/comics/compiling.png))
3. `ddf shell` - do your work

I don't typically use `ddf stop` until I need to do another make.

## 3. Conceptual Model
- Core Concepts
- Build Stages
- Build Hooks
- Cached resources
- Generated artifacts

### Core Concepts

| Concept | Description |
| :--- | :--- |
| Workspace | Refers to an instance of DDF, defined by a cloned repo and the associated projects 
| Project | Each code repo or code tree associated with a DDF workspace is a project. Projects can contain build hooks and other configuration metadata, and are mounted into the running workspace. |
| Build Hook | A shell script contributed by a project that customizes the docker build.  |
| Build Stage | One phase of the multi-part Docker build. In DDF the stages are: base, dev-core, dev-tooling, dev-gui, and prod |
| Image | A built Docker image produced by one build stage of the framework.  |
| Container | a running instance of one of the DDF images |

### Build Stages
The DDF Docker build has been separated into stages. While many operations can be done at virtually any point in the Docker build, DDF uses stages to separate responsibilities and encourage a conscious organization of installation tasks and build hooks. That, in turn, makes it easier to organize and visualize the build steps - which, for a workspace that included several complex projects, might be a complex task.

As with many hierarchical, staged environments, the earlier stages should become solid early on, and later changes will largely go in the later stages. This definitely works well with Docker build caching.

**base** is the stage common to both dev and prod image builds; it is effectively the common denomiator of all builds - the bare minimum that's needed to support both the development shell and the the minimalist production run. If a resource is needed to both develop and run the built project, it should be in base.

Typical contents:
- Base operating system resources
- User and group configuration
- Locale, timezone
- Networking
- Common runtime resources needed by the projects

*Rule of thumb*: Needed by both development and production

**dev-core** provides the general software development environment. This is what's needed to make the container a general software development environment. If every developer working on the project needs it, it should be in dev-core.

Typical contents:
- Compilers and languages
- Build tools (cmake,  ninja, bazel, etc)
- Package managers (npm, pip, etc.)
- Source control (git)
- editors

*Rule of thumb*: Needed for general software development.

**dev-tooling** is where project-specific technologies that suport development are installed and set up. This is technologies and resources specific to the projects being developed.

Typical contents:
- SDKs and vendor libraries
- Dev tooling for packages like ROS
- Language-specific package managers
- Custom tools
- Third-party frameworks

*Rule of thumb*: The project's tech stack needs it

**dev-gui** supports the graphical desktop environment. While `dev-tooling` is about building the software, `dev-gui` is about interacting with and running the software. This is where GUI build tools, support for the GUI environment or GUI projects are installed. 

Typical contents:
- X11/Wayland support
- Desktop utilities
- IDEs
- Visualization tools and image viewers
- GUI SDKs

*Rule of thumb*: Needed by only graphical tools or to support graphical development.

**prod** supports the deployed running of the project. It's intended to be a stripped-down, minimal, non-interactive environment that is deployed to a compute resource, and generally should start the project artifact running upon startup. Unlike the development stage, prod should contain only what's absolutely necessary to execute the built and installed application.

*Rule of thumb*: Only the finished application needs it to run.

### Build Hooks
DDF supports customization of the Docker build via the invocation of shell scripts in each build stage. The stages that can have hooks are: base, dev-core, dev-tooling, dev-gui, and prod. While many customizations could really be made at almost any point in the build, the stages 

### Cached Data

### Generated Artifacts


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
