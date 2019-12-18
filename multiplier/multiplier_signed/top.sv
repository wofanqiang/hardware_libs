module top
#(
    parameter NUM_ELEMENTS          = 17,
    parameter BIT_LEN               = 17,
    parameter WORD_LEN              = 16
)
(
    input clk,
    input logic signed [BIT_LEN:0] a[NUM_ELEMENTS],
    input logic signed [BIT_LEN:0] b[NUM_ELEMENTS],

    output logic signed [BIT_LEN:0] c[NUM_ELEMENTS*2+1]
);


    logic signed [BIT_LEN:0] reg_a[NUM_ELEMENTS];
    logic signed [BIT_LEN:0] reg_b[NUM_ELEMENTS];
    logic signed [BIT_LEN:0] u_c[NUM_ELEMENTS*2+1];


    always_ff @(posedge clk) begin
        reg_a   <= a;
        reg_b   <= b;
        c       <= u_c;
    end




    multiplier
    #(
        .NUM_ELEMENTS(NUM_ELEMENTS),
        .BIT_LEN(BIT_LEN),
        .WORD_LEN(WORD_LEN)
    ) u_multiplier_256
    (
        .a(reg_a),
        .b(reg_b),
        .c(u_c)
    );

endmodule