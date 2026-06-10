({
    handleToastEvent : function(component, event, helper) {
        // Called when any $A.get('e.force:showToast') fires in Lightning context
        console.log("⚡ handleToastEvent captured a force:showToast");
        var message = event.getParam("message") || '';
        var type = event.getParam("type") || 'info';
        component.set("v.toastMessage", message);

        // Optionally re-show a confirmation toast in the shell (useful for debugging)
        var toastEvent = $A.get("e.force:showToast");
        if (toastEvent) {
            toastEvent.setParams({
                "title": "Toast captured",
                "message": message,
                "type": type
            });
            toastEvent.fire();
        }
    },

    doInit : function(component, event, helper) {
        console.log("ToastMessageListener: doInit - attaching window message listener");

        // Compute allowed VF origin(s) if you know them; for demo we'll compute relative VF host param if provided
        // If you embed VF with vfHost attribute, you can set component attribute and use it here. For now we'll accept messages from any VF origin but log origin.
        window.addEventListener("message", function(e) {
            console.log("ToastMessageListener: received message", e.data, "from", e.origin);

            // Basic validation: expect object with type ShowToast or EventFromVF
            if (!e.data) return;
            // Accept either { type: 'ShowToast' , toastParams: {...} } or { type: 'EventFromVF', message: '...' }
            if (e.data.type === 'ShowToast' && e.data.toastParams) {
                var tp = e.data.toastParams;
                var toastEvent = $A.get("e.force:showToast");
                if (toastEvent) {
                    toastEvent.setParams(tp);
                    toastEvent.fire();
                }
                component.set("v.toastMessage", tp.message || JSON.stringify(tp));
                return;
            }
            if (e.data.type === 'EventFromVF' && e.data.message) {
                var toastEvent2 = $A.get("e.force:showToast");
                if (toastEvent2) {
                    toastEvent2.setParams({
                        "title": "Message from VF",
                        "message": e.data.message,
                        "type": "info"
                    });
                    toastEvent2.fire();
                }
                component.set("v.toastMessage", e.data.message);
                return;
            }
        }, false);
    }
})