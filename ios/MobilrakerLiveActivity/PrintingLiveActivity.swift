//
//  MobilrakerLiveActivityLiveActivity.swift
//  MobilrakerLiveActivity
//
//  Created by Patrick Schmidt on 08.09.23.
//

import ActivityKit
import WidgetKit
import SwiftUI

@main
struct MobilrakerLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        PrintingLiveActivity()
    }
}


struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState // don't forget to add this line, otherwise, live activity will not display it.
    
    public struct ContentState: Codable, Hashable {
        // make everything nullable to be able to retrieve initial
        // values before notification is sent to update
        let progress: Double?
        let eta: Int?
    }
    
    var id = UUID()
}

let sharedDefault = UserDefaults(suiteName: "group.mobileraker.liveactivity")!

struct PrintingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            let progress = context.state.progress ?? sharedDefault.double(forKey: context.attributes.prefixedKey(key: "progress"))
            let isPrintDone = abs(progress - 1) < 0.0001
            
            let state = sharedDefault.string(forKey: context.attributes.prefixedKey(key: "state"))!
            let file = sharedDefault.string(forKey: context.attributes.prefixedKey(key: "file"))!
            
            
            
            
            let eta = context.state.eta ?? sharedDefault.integer(forKey: context.attributes.prefixedKey(key: "eta"))
            let etaDate = eta > 0 ? Date(timeIntervalSince1970: TimeInterval(eta)) : nil
            
            
            let printStartUnix = sharedDefault.integer(forKey: context.attributes.prefixedKey(key: "printStartTime"))
            let printStartDate = Date(timeIntervalSince1970: TimeInterval(printStartUnix))
            
            let primaryColor = sharedDefault.integer(forKey: context.attributes.prefixedKey(key:"primary_color_light"))
            let machineName = sharedDefault.string(forKey: context.attributes.prefixedKey(key:"machine_name"))!
            let elapsedLabel = sharedDefault.string(forKey: context.attributes.prefixedKey(key:"elapsed_label"))!
            
            
            let backgroundColor = isPrintDone ? Color.green.opacity(0.45) : Color.white.opacity(0.45)

            //ToDo
            
            // Lock screen/banner UI goes here
            VStack(alignment: .leading, spacing: 8.0) {
                HStack{
                    VStack(alignment: .leading){
                        Text(machineName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(file)
                    }
                    
                    Spacer()
                    CircularProgressView(progress: progress, color_int: UInt32(primaryColor))
                }
                
                if !isPrintDone {
                    EtaDisplayView(activityContext: context, etaDate: etaDate)
                }
                
            }
            
            .padding(.all)
            //.foregroundColor(Color.black)
            .activityBackgroundTint(backgroundColor)
            .activitySystemActionForegroundColor(Color.black)
            
        } dynamicIsland: { context in
            let progress = context.state.progress ?? sharedDefault.double(forKey: context.attributes.prefixedKey(key:"progress"))
            let isPrintDone = abs(progress - 1) < 0.0001
            
            
            let state = sharedDefault.string(forKey: context.attributes.prefixedKey(key:"state"))!
            let file = sharedDefault.string(forKey: context.attributes.prefixedKey(key:"file"))!
            
            
            let eta = context.state.eta ?? sharedDefault.integer(forKey: context.attributes.prefixedKey(key:"eta"))
            let etaDate = eta > 0 ? Date(timeIntervalSince1970: TimeInterval(eta)) : nil
            
            
            let printStartUnix = sharedDefault.integer(forKey: context.attributes.prefixedKey(key:"printStartTime"))
            let printStartDate = Date(timeIntervalSince1970: TimeInterval(printStartUnix))
            
            
            let primaryColor = sharedDefault.integer(forKey:context.attributes.prefixedKey(key: "primary_color_dark"))
            let machineName = sharedDefault.string(forKey: context.attributes.prefixedKey(key:"machine_name"))!
            let elapsedLabel = sharedDefault.string(forKey: context.attributes.prefixedKey(key:"elapsed_label"))!
            
            return DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text(machineName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .padding(.leading, 2.0);
                    
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CircularProgressView(progress: progress, widthHeight: 25, lineWidth: 3.3, color_int: UInt32(primaryColor))
                        .padding(.horizontal)
                    
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading) {
                        Text(file)
                        if !isPrintDone {
                            EtaDisplayView(activityContext: context, etaDate: etaDate)
                            .frame(maxWidth: .infinity, alignment: .leading) // Expand to fill available space
                        }
                    }
                }
            } compactLeading: {
                let progress = context.state.progress ?? sharedDefault.double(forKey: context.attributes.prefixedKey(key:"progress"))
                let isPrintDone = abs(progress - 1) < 0.0001
                
                if isPrintDone {
                 Image("mr_logo")
                     .resizable()
                     .scaledToFit()
                } else {
                    let eta = context.state.eta ?? sharedDefault.integer(forKey: context.attributes.prefixedKey(key:"eta"))
                    let etaDate = eta > 0 ? Date(timeIntervalSince1970: TimeInterval(eta)) : nil
                    EtaDisplayViewCompact(etaDate: etaDate, width: 50)
                        .padding(.horizontal, 2.0)
                }
            } compactTrailing: {
                let progress = context.state.progress ?? sharedDefault.double(forKey: context.attributes.prefixedKey(key:"progress"))
                let isPrintDone = abs(progress - 1) < 0.0001
                let primaryColor = sharedDefault.integer(forKey: context.attributes.prefixedKey(key:"primary_color_dark"))
                CircularProgressView(progress: progress, widthHeight: 15, lineWidth: 2.5, color_int: UInt32(primaryColor))
                    .padding(.horizontal, 2.0)
                 
            } minimal: {
                let progress = context.state.progress ?? sharedDefault.double(forKey: context.attributes.prefixedKey(key:"progress"))
                let primaryColor = sharedDefault.integer(forKey: context.attributes.prefixedKey(key:"primary_color_dark"))
                CircularProgressView(progress: progress, widthHeight: 15, lineWidth: 2, color_int: UInt32(primaryColor))
                    .padding(.horizontal, 2.0)
            }
            .keylineTint(Color.red)
        }
    }
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(key: String) -> String {
        return "\(id)_\(key)"
    }
}
