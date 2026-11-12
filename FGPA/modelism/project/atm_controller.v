module atm_controller (
    input wire clk,
    input wire reset,

    // Events from the user / hardware
    input wire card_in,         // card inserted in slot
    input wire pin_entered,     // user finished typing the PIN
    input wire withdraw_req,    // user chose "Withdraw" in the menu
    input wire amount_entered,  // user confirmed the amount
    input wire cash_taken,      // user collected the cash
    input wire card_removed,    // card slot is empty again
    input wire cancel,          // user pressed Cancel

    // Answers from the bank / backend
    input wire pin_ok,          // PIN matches (valid while verify_pin = 1)
    input wire funds_ok,        // balance is enough (valid while check_funds = 1)

    // Moore outputs (depend only on the current state)
    output reg prompt_pin,      // screen: "Enter PIN"
    output reg verify_pin,      // ask bank to verify PIN
    output reg show_menu,       // screen: menu
    output reg prompt_amount,   // screen: "Enter amount"
    output reg check_funds,     // ask bank to check balance
    output reg dispense_cash,   // cash dispenser motor ON
    output reg show_no_funds,   // screen: "Insufficient funds"
    output reg eject_card,      // push card out of the slot
    output reg retain_card      // swallow the card (too many wrong PINs)
);

    // Moore FSM state encoding (10 states -> 4 bits)
    parameter IDLE         = 4'd0,
              PIN_ENTRY    = 4'd1,
              PIN_CHECK    = 4'd2,
              MENU         = 4'd3,
              AMOUNT_ENTRY = 4'd4,
              FUNDS_CHECK  = 4'd5,
              DISPENSE     = 4'd6,
              NO_FUNDS     = 4'd7,
              EJECT_CARD   = 4'd8,
              CARD_BLOCKED = 4'd9;

    reg [3:0] state, next_state;

    // Counts wrong PIN attempts (3rd wrong PIN blocks the card)
    reg [1:0] attempts;

    // State register
    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Wrong-PIN attempt counter
    always @(posedge clk or posedge reset) begin
        if (reset)
            attempts <= 2'd0;
        else begin
            case (state)
                IDLE: attempts <= 2'd0;
                PIN_CHECK: begin
                    if (pin_ok)
                        attempts <= 2'd0;
                    else
                        attempts <= attempts + 2'd1;
                end
                default: ;
            endcase
        end
    end

    // Next-state logic
    always @(*) begin
        next_state = state;

        case (state)
            IDLE:
                if (card_in)
                    next_state = PIN_ENTRY;

            PIN_ENTRY:
                if (cancel)
                    next_state = EJECT_CARD;
                else if (pin_entered)
                    next_state = PIN_CHECK;

            PIN_CHECK:
                if (pin_ok)
                    next_state = MENU;
                else if (attempts == 2'd2)      // this was the 3rd wrong PIN
                    next_state = CARD_BLOCKED;
                else
                    next_state = PIN_ENTRY;     // try again

            MENU:
                if (cancel)
                    next_state = EJECT_CARD;
                else if (withdraw_req)
                    next_state = AMOUNT_ENTRY;

            AMOUNT_ENTRY:
                if (cancel)
                    next_state = EJECT_CARD;
                else if (amount_entered)
                    next_state = FUNDS_CHECK;

            FUNDS_CHECK:
                if (funds_ok)
                    next_state = DISPENSE;
                else
                    next_state = NO_FUNDS;

            DISPENSE:
                if (cash_taken)
                    next_state = EJECT_CARD;

            NO_FUNDS:
                next_state = MENU;

            EJECT_CARD:
                if (card_removed)
                    next_state = IDLE;

            CARD_BLOCKED:
                if (card_removed)
                    next_state = IDLE;

            default:
                next_state = IDLE;
        endcase
    end

    // Moore output logic
    always @(*) begin
        prompt_pin    = 1'b0;
        verify_pin    = 1'b0;
        show_menu     = 1'b0;
        prompt_amount = 1'b0;
        check_funds   = 1'b0;
        dispense_cash = 1'b0;
        show_no_funds = 1'b0;
        eject_card    = 1'b0;
        retain_card   = 1'b0;

        case (state)
            PIN_ENTRY:    prompt_pin    = 1'b1;
            PIN_CHECK:    verify_pin    = 1'b1;
            MENU:         show_menu     = 1'b1;
            AMOUNT_ENTRY: prompt_amount = 1'b1;
            FUNDS_CHECK:  check_funds   = 1'b1;
            DISPENSE:     dispense_cash = 1'b1;
            NO_FUNDS:     show_no_funds = 1'b1;
            EJECT_CARD:   eject_card    = 1'b1;
            CARD_BLOCKED: retain_card   = 1'b1;
            default: ;
        endcase
    end

endmodule
