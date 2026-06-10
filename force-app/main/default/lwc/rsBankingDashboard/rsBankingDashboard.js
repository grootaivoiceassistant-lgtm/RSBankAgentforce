// rsBankingDashboard.js
//import RS_LOGO_SVG from '@salesforce/resourceUrl/RSLogoSVG';
import { LightningElement, api } from 'lwc';

export default class RsBankingDashboard extends LightningElement {
    @api customerName = 'Valued Customer';
    currentTimeIST = '';
    currentTip = 'Tip: Save regularly to maximize your 4.5% APY!';
    tips = [
        'Tip: Save regularly to maximize your 4.5% APY!',
        'Tip: Consider Fixed Deposits for 6.8% APY returns.',
        'Tip: Apply for a Home Loan starting at 7.2%.'
    ];
    tipIndex = 0;
    loanAmount = 10000;
    loanInterestRate = 8.5;
    loanTerm = 5;
    monthlyPayment = 0;
    showModal = false;
    showChatModal = false;
    modalTitle = '';
    modalContent = '';
    chatQuery = '';
    agentResponse = '';
    //logoUrl = RS_LOGO_SVG;

    // Service Modal Content
    serviceDetails = {
        savings: 'Benefits: 4.5% APY, easy access. Requirements: Minimum $100 deposit.',
        current: 'Benefits: Business-friendly, no minimum balance. Requirements: Business registration.',
        fixed: 'Benefits: 6.8% APY, secure investment. Requirements: Minimum $500 lock-in.',
        personalLoan: 'Benefits: Starting at 8.5%, flexible terms. Requirements: Credit score 650+.',
        homeLoan: 'Benefits: Starting at 7.2%, low EMI. Requirements: Property documentation.',
        investment: 'Benefits: Expert advice, diverse options. Requirements: Consultation required.'
    };

    connectedCallback() {
        this.updateTime();
        this.rotateTips();
        this.calculateMonthlyPayment();
        setInterval(() => this.updateTime(), 1000);
        setInterval(() => this.rotateTips(), 5000);
    }

    updateTime() {
        const now = new Date().toLocaleString('en-US', {
            timeZone: 'Asia/Kolkata',
            hour12: true,
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        });
        this.currentTimeIST = `IST: ${now}`;
    }

    rotateTips() {
        this.tipIndex = (this.tipIndex + 1) % this.tips.length;
        this.currentTip = this.tips[this.tipIndex];
    }

    handleLoanAmountChange(event) {
        this.loanAmount = parseFloat(event.target.value) || 0;
        this.calculateMonthlyPayment();
    }

    handleLoanInterestRateChange(event) {
        this.loanInterestRate = parseFloat(event.target.value) || 0;
        this.calculateMonthlyPayment();
    }

    handleLoanTermChange(event) {
        this.loanTerm = parseFloat(event.target.value) || 0;
        this.calculateMonthlyPayment();
    }

    calculateMonthlyPayment() {
        const principal = this.loanAmount;
        const interestRate = this.loanInterestRate / 100 / 12;
        const months = this.loanTerm * 12;
        if (principal > 0 && interestRate > 0 && months > 0) {
            this.monthlyPayment =
                (principal * interestRate * Math.pow(1 + interestRate, months)) /
                (Math.pow(1 + interestRate, months) - 1);
        } else {
            this.monthlyPayment = 0;
        }
    }

    get formattedMonthlyPayment() {
        return `$${this.monthlyPayment.toFixed(2)}`;
    }

    openServiceModal(event) {
        const service = event.target.dataset.service;
        this.modalTitle = `${service.charAt(0).toUpperCase() + service.slice(1)} Details`;
        this.modalContent = this.serviceDetails[service] || 'Details not available.';
        this.showModal = true;
    }

    closeModal() {
        this.showModal = false;
    }

    openChatModal() {
        this.showChatModal = true;
    }

    closeChatModal() {
        this.showChatModal = false;
        this.chatQuery = '';
        this.agentResponse = '';
    }

    handleChatQueryChange(event) {
        this.chatQuery = event.target.value;
    }

    sendToAgent() {
        this.agentResponse = `Mock response to: "${this.chatQuery}". In a real setup, this would connect to your Agentforce agent.`;
        this.chatQuery = '';
    }

    shareWithAgent() {
        this.agentResponse = `Shared Loan Details: Amount: $${this.loanAmount}, Rate: ${this.loanInterestRate}%, Term: ${this.loanTerm} years, Monthly: ${this.formattedMonthlyPayment}.`;
        this.openChatModal();
    }

    // Banking actions (mock)
    handleCheckBalance() { alert('Check Balance functionality here.'); }
    handleTransferFunds() { alert('Transfer Funds functionality here.'); }
    handlePayBills() { alert('Pay Bills functionality here.'); }
    handleOpenAccount() { this.openChatModal(); }
    handleLoanApplication() { this.openChatModal(); }
    handleInvestNow() { this.openChatModal(); }
}