sudo apt update

sudo apt install ros-melodic-gazebo-msgs -y
sudo apt install ros-melodic-gazebo-ros -y
sudo apt install ros-melodic-jackal* -y
sudo apt install ros-melodic-microstain* -y

#sudo sh -c 'echo "deb http://packages.osrfoundation.org/gazebo/ubuntu-stable `lsb_release -cs` main" > /etc/apt/sources.list.d/gazebo-stable.list'
#wget http://packages.osrfoundation.org/gazebo.key -O - | sudo apt-key add -
#sudo apt update
sudo apt upgrade -y

sudo apt-get install ros-melodic-slam-gmapping -y
sudo apt-get install ros-melodic-teleop-twist-keyboard -y
sudo apt-get install ros-melodic-controller-manager -y
sudo apt-get install ros-melodic-velodyne* -y
sudo apt-get install ros-melodic-gazebo-* -y
sudo apt-get install ros-melodic-effort-* -y
sudo apt-get install ros-melodic-position-* -y
sudo apt-get install ros-melodic-velocity-* -y

sudo apt-get install ros-melodic-ros-control -y
sudo apt-get install ros-melodic-joint-state-controller -y
sudo apt-get install ros-melodic-effort-controllers -y
sudo apt-get install ros-melodic-position-controllers -y
sudo apt-get install ros-melodic-velocity-controllers -y
sudo apt-get install ros-melodic-ros-controllers -y
sudo apt-get install ros-melodic-gazebo-ros -y
sudo apt-get install ros-melodic-gazebo-ros-control -y
sudo apt-get install ros-melodic-jsk -y

rosdep install --from-paths src --ignore-src -r -y

source /opt/ros/melodic/setup.bash
catkin_make
source devel/setup.bash