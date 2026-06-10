({
    showToast : function(component, event, helper) {
        console.log("ToastFromVF: showToast clicked");
        var toastEvent = $A.get("e.force:showToast");
        if (toastEvent) {
            toastEvent.setParams({
                "title": "ToastFromVF",
                "message": component.get("v.message"),
                "type": "success"
            });
            toastEvent.fire();
            console.log("ToastFromVF: toast fired");
        } else {
            // if not in Lightning runtime, fallback to console
            console.warn("$A.get('e.force:showToast') not available here");
        }
    }
})