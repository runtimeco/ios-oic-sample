//
//  ViewController.swift
//  ocf-sample
//
//  Created by Brian Giori on 9/6/17.
//  Copyright © 2017 Brian Giori. All rights reserved.
//

import UIKit
import CoreBluetooth

/**
 This view controller performs OIC actions over IP and BLE transports to
 devices which conform to the Binary Switch resource type. For mynewt
 devices, this could be either the iptest or bleprph_oic sample apps.
 
 When this view controller is loaded, multicast discovery will be
 performed over BLE and IP (for BLE this means doing unicast discovery
 on any device advertising the Iotivity UUID).
 
 When a device with a resource of type "oic.r.switch.binary" is found,
 the app will first get the switch's value then begin observing the
 resource for 5 seconds. Two seconds after getting the initial value,
 we will toggle the switch by PUTing the negated value we recieved from
 the GET.
 */
class ViewController: UIViewController, CBCentralManagerDelegate {
    
    @IBOutlet weak var log: UITextView!
    
    // MARK: - Properties
    
    // Light resources
    var ipLightResource: OcResource?
    var bleLightResource: OcResource?
    
    // Bluetooth
    var centralManager: CBCentralManager?
    var peripherals = [String: CBPeripheral]()
    
    //MARK: - View Controller
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Give Iotivity time to set up it's internal BLE client
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(1), execute: {
            // Start the centralManager which will begin scanning
            self.centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
            // Perform Multicast discovery over IP
            IotivityClient.shared().discoverMulticast(CT_ADAPTER_IP, callback: self.discoverCallback)
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Core Bluetooth
    func centralManagerDidUpdateState(_ centralManager: CBCentralManager) {
        // Begin scanning for peripherals
        self.centralManager!.scanForPeripherals(withServices: [CBUUID(string: IOTIVITY_UUID)], options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        peripherals.updateValue(peripheral, forKey: peripheral.identifier.uuidString)
        printLog("Peripheral found: name=\(peripheral.name ?? "Unknown"), id=\(peripheral.identifier.uuidString)")
        printLog("Discovering resources for new OCF host...")
        IotivityClient.shared().discoverUnicast(peripheral.identifier.uuidString, connType:CT_ADAPTER_GATT_BTLE, qos:OC_LOW_QOS, callback:discoverCallback)
    }
    
    // MARK: - Iotivity Callbacks
    
    // Discovery callback. This will be called every time a new OCF hosts is discovered.
    lazy var discoverCallback: DiscoverCallback = { [unowned self] (resources: [OcResource]!) in
        self.printLog("Resources discovered!")
        // Loop through and log each discovered resource
        for resource in resources {
            self.printLog(resource.description);
            // Set the light resource if one is found which has a resource type
            // matching the OCF binary switch type.
            if resource.resourceTypes.contains("oic.r.switch.binary") {
                // Use the resource's adapter to determine the transport
                self.printLog("Found light resource! Getting values...", withTransport: resource.adapterType)
                if resource.adapterType == OC_ADAPTER_IP {
                    self.ipLightResource = resource
                    // Call GET on IP light resource
                    self.ipLightResource!.get(self.getLightResourceCallback)
                } else if resource.adapterType == OC_ADAPTER_GATT_BTLE {
                    self.bleLightResource = resource
                    // Call GET on BLE light resource
                    self.bleLightResource!.get(self.getLightResourceCallback)
                }
            }
        }
    }
    
    // GET Callback
    lazy var getLightResourceCallback: GetCallback = { [unowned self] (representation: OcRepresentation?) in
        // Check for an Iotivity stack error
        if (representation?.result.rawValue)! > OC_STACK_RESOURCE_CHANGED.rawValue {
            self.printLog("GET Callback - Iotivity Error: \(representation!.result)", withTransport: representation?.adapterType)
            return
        }
        // Get values from the resource's representation
        if let values = representation?.values {
            // Get the boolean value with the name "value" from values
            if let value = values["value"] as? Bool {
                self.printLog("Got value from light resource: value=\(value)", withTransport: representation?.adapterType)
                self.printLog("Observing light value...", withTransport: representation?.adapterType)
                // Call observe on the resource
                if representation?.adapterType == OC_ADAPTER_IP {
                    self.ipLightResource?.observe(self.observeLightResourceCallback)
                } else if representation?.adapterType == OC_ADAPTER_GATT_BTLE {
                    self.bleLightResource?.observe(self.observeLightResourceCallback)
                }
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(5), execute: {
                    self.printLog("Cancelling observe of the light resource.", withTransport: representation?.adapterType)
                    if representation?.adapterType == OC_ADAPTER_IP {
                        self.ipLightResource?.cancelObserve()
                    } else if representation?.adapterType == OC_ADAPTER_GATT_BTLE {
                        self.bleLightResource?.cancelObserve()
                    }
                })
                // Put the light after a two second delay
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + .seconds(2), execute: {
                    // Create a OcRepresentationValue to PUT to the light resource
                    self.printLog("Putting value to light resource...", withTransport: representation?.adapterType)
                    var putValue = OcRepresentationValue(name: "value", boolValue: !value)
                    if representation?.adapterType == OC_ADAPTER_IP {
                        self.ipLightResource?.put([putValue!], callback: self.putLightResourceCallback)
                    } else if representation?.adapterType == OC_ADAPTER_GATT_BTLE {
                        self.bleLightResource?.put([putValue!], callback: self.putLightResourceCallback)
                    }
                })
            } else {
                self.printLog("GET Callback - values does not contain a value with name \"value\"", withTransport: representation?.adapterType)
            }
        } else {
            self.printLog("GET Callback - representation does not contain any values", withTransport: representation?.adapterType)
        }
    }
    
    // OBSERVE Callback
    lazy var observeLightResourceCallback: ObserveCallback = { [unowned self] (representation: OcRepresentation?) in
        // Check for an Iotivity stack error. Error codes start after OC_STACK_RESOURCE_CHANGED (4).
        if (representation?.result.rawValue)! > OC_STACK_RESOURCE_CHANGED.rawValue {
            self.printLog("OBSERVE Callback - Iotivity Error: \(representation!.result)", withTransport: representation?.adapterType)
            return
        }
        // Get values from the resource's representation
        if let values = representation?.values {
            // Get the boolean value with the name "value" from values
            if let value = values["value"] as? Bool {
                self.printLog("OBSERVE Callback: value=\(value)", withTransport: representation?.adapterType)
            } else {
                self.printLog("OBSERVE Callback - values does not contain a value with name \"value\"", withTransport: representation?.adapterType)
            }
        } else {
            self.printLog("OBSERVE Callback - representation does not contain any values", withTransport: representation?.adapterType)
        }
    }
    
    //PUT CALLBACK
    lazy var putLightResourceCallback: PutCallback = { [unowned self] (representation: OcRepresentation?) in
        // Check for an Iotivity stack error
        if (representation?.result.rawValue)! > OC_STACK_RESOURCE_CHANGED.rawValue {
            self.printLog("PUT Callback - Iotivity Error: \(representation!.result)", withTransport: representation?.adapterType)
            return
        }
        self.printLog("PUT Callback - Success.", withTransport: representation?.adapterType)
    }
    
    // MARK: - Logging Function
    func printLog(_ text:String, withTransport: OCTransportAdapter? = nil) {
        print(text)
        var transport = ""
        if withTransport == OC_ADAPTER_IP {
            transport = "IP: "
        } else if withTransport == OC_ADAPTER_GATT_BTLE {
            transport = "BLE: "
        }
        self.log.text.append("\(transport)\(text)\n")
    }

}

