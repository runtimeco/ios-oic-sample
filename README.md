# ios-oic-sample
This app is a sample for iOS apps using [runtimeco's Iotivity fork](https://github.com/runtimeco/iotivity/tree/1.1.1_android_darwin) to communicate using OIC to devices running [Apache Mynewt](https://github.com/apache/mynewt-core). If you are looking to develop your own iOS app using runtimeco's Iotivity fork, try to initially emulate this app's Build Settings or simply clone this repository and rename the project. 

## iOS App Setup (Client)
Cloning the app and setting up Iotivity is a snap. Just follow these simple steps:

1. Navigate to your desired directory and clone this repository: `git clone https://github.com/runtimeco/ios-oic-sample`
2. Change directory to the newly cloned project: `cd ios-oic-sample`
3. Run the setup script to clone and set up Iotivity: `./setup.sh`
4. Open `oic-sample.xcodeproj` in XCode and run!

## Mynewt App Setup (Server)
In order to use ios-oic-sample, there must be an active BLE or IP OIC server which hosts a resource which conforms to the Binary Switch Resource Type to communicate with. For Mynewt devices, you can use `iptest` (for IP transport), `bleprph_oic` (for BLE transport) or run both. 

If you are new to Mynewt, I would reccomend you start by [setting up your environment](http://mynewt.apache.org/latest/os/get_started/native_install_intro/) and get [project blinky](http://mynewt.apache.org/latest/os/tutorials/blinky/) working before continuing on.

### iptest (IP, Easiest)

If you don't have any hardware don't worry! Iptest works just as well on the simulator which you can run from your computer. First create your target to match the following:

```
targets/ip_sim
    app=@apache-mynewt-core/apps/iptest
    bsp=@apache-mynewt-core/hw/bsp/native
    build_profile=debug
    syscfg=BUILD_WITH_OIC=1:LOG_LEVEL=0:OC_DEBUG=1:OC_LOGGING=1:OC_SERVER=1:OC_TRANSPORT_IP=1:OC_TRANSPORT_IPV4=1:OC_TRANSPORT_IPV6=0
```
Next, run your target (`newt run ip_sim`) and run gdb (`r`).

The final step is opening the command line interface at the port printed after running the simulator in gdb: `uart0 at /dev/ttysXXX`. 

Open this device using your favorite terminal emulator (in this case I'm using minicom) and hit enter to access the CLI prompt. 

```
Welcome to minicom 2.7.1

OPTIONS: 
Compiled on May 17 2017, 15:29:14.
Port /dev/ttys006, 14:13:29

Press Meta-Z for help on special keys


000722 compat> net oic
000897 compat>
``` 
Finally, use the command `net oic` to start the OIC server.

### bleprph_oic (BLE)

To use bleprph_oic set up a target to match the following, modifying the bsp to match the board you're using.

```
targets/nrf52
    app=@apache-mynewt-core/apps/bleprph_oic
    bsp=@apache-mynewt-core/hw/bsp/<your_bsp_here>
    build_profile=debug
    syscfg=ADVERTISE_128BIT_UUID=1:ADVERTISE_16BIT_UUID=0

```


## Using ios-oic-sample
First, set up your server before starting ios-oic-sample.

On startup, ios-oic-sample begins resource discovery over IP and BLE transports simultaneously. Discovery over BLE and IP are slightly different but essentially amount to the same thing. Over IP, resource discovery is multicasted to any listening servers. BLE, without any built in Multicast functionality, relies on iOS's CoreBluetooth framework to scan for BLE advertisements containing the Iotivity UUID, then performs unicast discovery on each device individially. Although the two transports perform discovery differently, they both share the same callback where we differentiate the transports based on the `OcResource`'s adapter type (either `OC_ADAPTER_IP` or `OC_ADAPTER_GATT_BTLE`).

When a reponse is received from a server over either transport, we then check the sequence of resources for one which contains the Binary Switch Resource Type (`"oic.r.switch.binary"`) string. Once found, we perform a GET operation on this resource. After receiving the GET callback, we begin to observe the resource for 5 seconds and queue a PUT to trigger after 2 seconds. 

In the end, we should be able to see the light resource value toggle after the PUT occurs.

