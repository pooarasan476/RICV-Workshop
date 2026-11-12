`timescale 1ns/1ps

module atm_controller_tb;

    reg clk;
    reg reset;
    reg card_in;
    reg pin_entered;
    reg withdraw_req;
    reg amount_entered;
    reg cash_taken;
    reg card_removed;
    reg cancel;
    reg pin_ok;
    reg funds_ok;

    wire prompt_pin;
    wire verify_pin;
    wire show_menu;
    wire prompt_amount;
    wire check_funds;
    wire dispense_cash;
    wire show_no_funds;
    wire eject_card;
    wire retain_card;

    integer errors;

    // Device under test
    atm_controller uut (
        .clk(clk),
        .reset(reset),
        .card_in(card_in),
        .pin_entered(pin_entered),
        .withdraw_req(withdraw_req),
        .amount_entered(amount_entered),
        .cash_taken(cash_taken),
        .card_removed(card_removed),
        .cancel(cancel),
        .pin_ok(pin_ok),
        .funds_ok(funds_ok),
        .prompt_pin(prompt_pin),
        .verify_pin(verify_pin),
        .show_menu(show_menu),
        .prompt_amount(prompt_amount),
        .check_funds(check_funds),
        .dispense_cash(dispense_cash),
        .show_no_funds(show_no_funds),
        .eject_card(eject_card),
        .retain_card(retain_card)
    );

    // 10 ns clock period
    always #5 clk = ~clk;

    // Inputs are changed on the falling edge, the DUT samples on the rising edge
    task tick;
        begin
            @(negedge clk);
        end
    endtask

    // Compare the current state and report
    task check_state;
        input [3:0] expected;
        input [8*13:1] name;
        begin
            if (uut.state === expected)
                $display("  PASS: state = %0s", name);
            else begin
                $display("  FAIL: expected %0s (%0d), got %0d", name, expected, uut.state);
                errors = errors + 1;
            end
        end
    endtask

    // Check one output bit
    task check_out;
        input actual;
        input [8*13:1] name;
        begin
            if (actual !== 1'b1) begin
                $display("  FAIL: output %0s should be 1", name);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // Initialize inputs
        clk            = 1'b0;
        reset          = 1'b1;
        card_in        = 1'b0;
        pin_entered    = 1'b0;
        withdraw_req   = 1'b0;
        amount_entered = 1'b0;
        cash_taken     = 1'b0;
        card_removed   = 1'b0;
        cancel         = 1'b0;
        pin_ok         = 1'b0;
        funds_ok       = 1'b0;
        errors         = 0;

        // Reset
        #12;
        reset = 1'b0;
        tick;
        check_state(uut.IDLE, "IDLE");

        // ---------------------------------------------------------
        // Test 1: correct PIN, enough money, cash withdrawn
        // ---------------------------------------------------------
        $display("Test 1: normal withdrawal");
        card_in = 1'b1;  tick;  card_in = 1'b0;
        check_state(uut.PIN_ENTRY, "PIN_ENTRY");
        check_out(prompt_pin, "prompt_pin");

        pin_ok = 1'b1;  pin_entered = 1'b1;  tick;  pin_entered = 1'b0;
        check_state(uut.PIN_CHECK, "PIN_CHECK");
        check_out(verify_pin, "verify_pin");

        tick;
        check_state(uut.MENU, "MENU");
        check_out(show_menu, "show_menu");

        withdraw_req = 1'b1;  tick;  withdraw_req = 1'b0;
        check_state(uut.AMOUNT_ENTRY, "AMOUNT_ENTRY");
        check_out(prompt_amount, "prompt_amount");

        funds_ok = 1'b1;  amount_entered = 1'b1;  tick;  amount_entered = 1'b0;
        check_state(uut.FUNDS_CHECK, "FUNDS_CHECK");
        check_out(check_funds, "check_funds");

        tick;
        check_state(uut.DISPENSE, "DISPENSE");
        check_out(dispense_cash, "dispense_cash");

        cash_taken = 1'b1;  tick;  cash_taken = 1'b0;
        check_state(uut.EJECT_CARD, "EJECT_CARD");
        check_out(eject_card, "eject_card");

        card_removed = 1'b1;  tick;  card_removed = 1'b0;
        check_state(uut.IDLE, "IDLE");

        pin_ok = 1'b0;  funds_ok = 1'b0;

        // ---------------------------------------------------------
        // Test 2: one wrong PIN, then correct PIN, insufficient funds, cancel
        // ---------------------------------------------------------
        $display("Test 2: wrong PIN once, no funds, cancel");
        card_in = 1'b1;  tick;  card_in = 1'b0;
        check_state(uut.PIN_ENTRY, "PIN_ENTRY");

        pin_ok = 1'b0;  pin_entered = 1'b1;  tick;  pin_entered = 1'b0;
        check_state(uut.PIN_CHECK, "PIN_CHECK");
        tick;
        check_state(uut.PIN_ENTRY, "PIN_ENTRY");   // wrong PIN -> try again

        pin_ok = 1'b1;  pin_entered = 1'b1;  tick;  pin_entered = 1'b0;
        tick;
        check_state(uut.MENU, "MENU");

        withdraw_req = 1'b1;  tick;  withdraw_req = 1'b0;
        funds_ok = 1'b0;  amount_entered = 1'b1;  tick;  amount_entered = 1'b0;
        check_state(uut.FUNDS_CHECK, "FUNDS_CHECK");

        tick;
        check_state(uut.NO_FUNDS, "NO_FUNDS");
        check_out(show_no_funds, "show_no_funds");

        tick;
        check_state(uut.MENU, "MENU");

        cancel = 1'b1;  tick;  cancel = 1'b0;
        check_state(uut.EJECT_CARD, "EJECT_CARD");

        card_removed = 1'b1;  tick;  card_removed = 1'b0;
        check_state(uut.IDLE, "IDLE");

        pin_ok = 1'b0;

        // ---------------------------------------------------------
        // Test 3: three wrong PINs -> card is retained
        // ---------------------------------------------------------
        $display("Test 3: three wrong PINs");
        card_in = 1'b1;  tick;  card_in = 1'b0;
        check_state(uut.PIN_ENTRY, "PIN_ENTRY");

        // Wrong PIN, attempt 1
        pin_entered = 1'b1;  tick;  pin_entered = 1'b0;  tick;
        check_state(uut.PIN_ENTRY, "PIN_ENTRY");
        // Wrong PIN, attempt 2
        pin_entered = 1'b1;  tick;  pin_entered = 1'b0;  tick;
        check_state(uut.PIN_ENTRY, "PIN_ENTRY");
        // Wrong PIN, attempt 3
        pin_entered = 1'b1;  tick;  pin_entered = 1'b0;  tick;
        check_state(uut.CARD_BLOCKED, "CARD_BLOCKED");
        check_out(retain_card, "retain_card");

        card_removed = 1'b1;  tick;  card_removed = 1'b0;
        check_state(uut.IDLE, "IDLE");

        tick;
        if (uut.attempts === 2'd0)
            $display("  PASS: attempt counter cleared");
        else begin
            $display("  FAIL: attempt counter not cleared");
            errors = errors + 1;
        end

        // ---------------------------------------------------------
        if (errors == 0)
            $display("ALL TESTS PASSED: ATM controller works!");
        else
            $display("TEST FAILED: %0d error(s)", errors);

        #10;
        $finish;
    end

    // Display state and outputs
    initial begin
        $monitor(
            "Time=%0t | State=%0d | PIN?=%b VER=%b MENU=%b AMT=%b FUND=%b CASH=%b NOFUND=%b EJECT=%b KEEP=%b",
            $time, uut.state, prompt_pin, verify_pin, show_menu, prompt_amount,
            check_funds, dispense_cash, show_no_funds, eject_card, retain_card
        );
    end

endmodule
