module top
#(
    parameter NUM_ELEMENTS          = 17,
    parameter BIT_LEN               = 17,
    parameter WORD_LEN              = 16
    )
    (
        input clk,
        input logic [BIT_LEN-1:0] A[NUM_ELEMENTS],
        input logic [BIT_LEN-1:0] B[NUM_ELEMENTS],
        output logic [BIT_LEN-1:0] M[NUM_ELEMENTS*2]
    );
    
    logic [BIT_LEN-1:0] A_reg[NUM_ELEMENTS];
    logic [BIT_LEN-1:0] B_reg[NUM_ELEMENTS];
    logic [BIT_LEN-1:0] u_M[NUM_ELEMENTS*2];
    
    always_ff@(posedge clk)begin
        A_reg <= A;
        B_reg <= B;
        M <= u_M;
    end
    
    multiplier
    #(
        .NUM_ELEMENTS(NUM_ELEMENTS),
        .BIT_LEN(BIT_LEN),
        .WORD_LEN(WORD_LEN)
    ) u_mul_256 (
        .A(A_reg),
        .B(B_reg),
        .M(u_M)
    );
    
endmodule
