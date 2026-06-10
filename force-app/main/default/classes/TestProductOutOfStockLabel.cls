@isTest
private class TestProductOutOfStockLabel {
    @isTest
    static void testLabelInSpanishContext() {
        // Create a test Spanish user
        User spanishUser = new User(
            Alias = 'testsp',
            Email = 'testspanish@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TestSpanish',
            LanguageLocaleKey = 'es',
            LocaleSidKey = 'es_MX',
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Identity User' LIMIT 1].Id,
            TimeZoneSidKey = 'America/Mexico_City',
            UserName = 'testspanish' + System.currentTimeMillis() + '@example.com'
        );
        insert spanishUser;
        
        // Test in the Spanish user's context
        System.runAs(spanishUser) {
            String message = Label.Product_Out_Of_Stock;
            System.assertEquals('Lo sentimos, este producto está actualmente agotado', message, 'Label should be in Spanish');
            System.assertEquals('Lo sentimos, este producto está actualmente agotado', message, 'Label should be in Spanish');
            System.debug('Test Message: ' + message);
        }
    }
    @isTest
    static void testLabelInFrenchContext() {
        // Create a test French user
        User frenchUser = new User(
            Alias = 'testfr',
            Email = 'testfrench@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TestFrench',
            LanguageLocaleKey = 'fr',  // French
            LocaleSidKey = 'fr_FR',    // French locale
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            TimeZoneSidKey = 'Europe/Paris',
            UserName = 'testfrench' + System.currentTimeMillis() + '@example.com'
        );
        insert frenchUser;
        
        // Test in the French user's context
        System.runAs(frenchUser) {
            String message = Label.Product_Out_Of_Stock;
            System.assertEquals('Désolé, ce produit est actuellement en rupture de stock', message, 'Label should be in French');
            System.debug('Test Message: ' + message);
        }
    }
    @isTest
    static void testLabelInEnglishContext() {
        // Create a test English user
        User englishUser = new User(
            Alias = 'testen',
            Email = 'testenglish@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'TestEnglish',
            LanguageLocaleKey = 'en_US',  // English
            LocaleSidKey = 'en_US',       // English locale
            ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1].Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testenglish' + System.currentTimeMillis() + '@example.com'
        );
        insert englishUser;
        
        // Test in the English user's context
        System.runAs(englishUser) {
            String message = Label.Product_Out_Of_Stock;
            System.assertEquals('Sorry, this product is currently out of stock', message, 'Label should be in English');
            System.debug('Test Message: ' + message);
        }
    }
}