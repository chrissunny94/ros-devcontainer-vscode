# ROS1 container for Gazebo 

- Jackal robot with 3D Lidar , Camera , Gmapping , MOVE_BASE

- using technology such as Docker , Docker-compose and noVNC has allowed me to create a easy to use project that could be cloned and used .
- Since this is dockerized , you dont need to install any additional dependencies or break your head over issues with respect to compilation and broken packages .



# Preparation 

![](docs/reopen_in_container.png)
![](docs/initializing_the_container.png)
![](docs/pull_docker_image.png)
![](docs/nvidia_container.png)



**Then once the container is spwaned properly  use the scripts to do the respective**

# How to use this repository

### To start a basic jackal robot in Gazebo Simulation use this following 

```
./run_jackal_sim.sh

```

### To start a lidar based obstacle detection/clustering node ,use the following script 

```
./run_lidar_obstacle_detector.sh
```

### To start Eucledian Clustering / Hungarian Algorithm 

```
./run_adaptive_clustering.sh

```


### To start ground plane extraction , free space detection  

```
./run_urba_road_filter.sh

```



#### Follow the instructions and install docker 

- https://docs.docker.com/engine/install/ubuntu/
- https://stackoverflow.com/questions/48957195/how-to-fix-docker-got-permission-denied-issue
