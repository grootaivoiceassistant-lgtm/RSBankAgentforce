trigger RSBankAccountTrigger on RS_Bank_Account__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        RSBankAccountTriggerHandler.handleAfterInsert(Trigger.new);
    }
}