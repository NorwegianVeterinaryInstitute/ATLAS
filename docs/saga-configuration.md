# Directory paths
The following directory paths are used on Saga:

```
Project directory:      /cluster/projects/nn9305k/projects
Active data directory:  /cluster/shared/vetinst/active_data
Freeze directory:       /nird/datapeak/NS9305K/study_freezer
Archive directory:      /nird/datalake/NS9305K/study_archive
```

# Saga configuration
For ATLAS to work on Saga, all users need to set the variable `XDG_CONFIG_HOME` in their `$HOME/.bashrc` file.

Open your .bashrc file in nano:
```
nano $HOME/.bashrc
```

Add the following line at the end of the file:
```
export XDG_CONFIG_HOME=/cluster/projects/nn9305k/.config/
```

Save the file and log out and back in. ATLAS is now configured with the proper directory paths.