module multiplier
#(
    parameter NUM_ELEMENTS          = 17,
    parameter BIT_LEN               = 17,
    parameter WORD_LEN              = 16
)
(
    input logic signed [BIT_LEN:0] a[NUM_ELEMENTS],
    input logic signed [BIT_LEN:0] b[NUM_ELEMENTS],

    output logic signed [BIT_LEN:0] c[NUM_ELEMENTS*2+1]
);

    localparam EXTRA_BIT = $clog2(NUM_ELEMENTS)+2;


    logic signed [BIT_LEN*2:0] p[NUM_ELEMENTS][NUM_ELEMENTS];

    logic [BIT_LEN*2-1:0] p_abs[NUM_ELEMENTS][NUM_ELEMENTS];

    logic signed [WORD_LEN:0] p_0[NUM_ELEMENTS][NUM_ELEMENTS];
    logic signed [WORD_LEN:0] p_1[NUM_ELEMENTS][NUM_ELEMENTS];
    logic signed [WORD_LEN:0] p_2[NUM_ELEMENTS][NUM_ELEMENTS];

    
    always_comb begin
        for(int r=0; r <NUM_ELEMENTS; r++)begin:mul_array_row
            for(int c=0; c<NUM_ELEMENTS; c++)begin:mul_array_col
                p[r][c] = a[r] * b[c];
                p_abs[r][c] = (p[r][c][BIT_LEN*2])? ~p[r][c] + 1 : p[r][c];
                p_0[r][c] = (p[r][c][BIT_LEN*2])? -p_abs[r][c][WORD_LEN-1:0] : p_abs[r][c][WORD_LEN-1:0];
                p_1[r][c] = (p[r][c][BIT_LEN*2])? -p_abs[r][c][WORD_LEN*2-1:WORD_LEN] : p_abs[r][c][WORD_LEN*2-1:WORD_LEN];
                p_2[r][c] = (p[r][c][BIT_LEN*2])? -p_abs[r][c][BIT_LEN*2-1:WORD_LEN*2]: p_abs[r][c][BIT_LEN*2-1:WORD_LEN*2];
            end
        end
    end

    logic signed [WORD_LEN+EXTRA_BIT:0] sum_0[NUM_ELEMENTS*2-1];
    logic signed [WORD_LEN+EXTRA_BIT:0] sum_1[NUM_ELEMENTS*2-1];
    logic signed [WORD_LEN+EXTRA_BIT:0] sum_2[NUM_ELEMENTS*2-1];


    always_comb begin
        for (int c = 0; c < NUM_ELEMENTS*2-1; c++) begin
            if (c < NUM_ELEMENTS) begin
                for (int i = 0; i < c+1; i++) begin
                    if (i == 0) begin
                        sum_0[c] = p_0[i][c-i];
                        sum_1[c] = p_1[i][c-i];
                        sum_2[c] = p_2[i][c-i];
                    end else begin
                        sum_0[c] = sum_0[c] + p_0[i][c-i];
                        sum_1[c] = sum_1[c] + p_1[i][c-i];
                        sum_2[c] = sum_2[c] + p_2[i][c-i];
                    end
                end
            end else begin
                for (int j = NUM_ELEMENTS-1; j > c-NUM_ELEMENTS; j--) begin
                    if (j == NUM_ELEMENTS-1) begin
                        sum_0[c] = p_0[j][c-j];
                        sum_1[c] = p_1[j][c-j];
                        sum_2[c] = p_2[j][c-j];
                    end else begin
                        sum_0[c] = sum_0[c] + p_0[j][c-j];
                        sum_1[c] = sum_1[c] + p_1[j][c-j];
                        sum_2[c] = sum_2[c] + p_2[j][c-j];
                    end
                end
            end
        end
    end

    logic signed [WORD_LEN+EXTRA_BIT+1:0] c_temp[NUM_ELEMENTS*2+2];
    logic signed [WORD_LEN:0] c_temp_0[NUM_ELEMENTS*2+2];
    logic signed [WORD_LEN:0] c_temp_1[NUM_ELEMENTS*2+2];
    logic signed [WORD_LEN*2-1:0] c_temp_abs[NUM_ELEMENTS*2+2];


    always_comb begin
        for (int i = 0; i < NUM_ELEMENTS*2+1; i++) begin
            if (i == 0) begin
                c_temp[i] = sum_0[0];
            end else if (i == 1) begin
                c_temp[i] = sum_0[1] + sum_1[0];
            end else if (i == NUM_ELEMENTS*2-1) begin
                c_temp[i] = sum_1[NUM_ELEMENTS*2-2] + sum_2[NUM_ELEMENTS*2-3];
            end else if (i == NUM_ELEMENTS*2) begin
                c_temp[i] = sum_2[NUM_ELEMENTS*2-2];
            end else begin
                c_temp[i] =  sum_0[i] + sum_1[i-1] + sum_2[i-2];
            end
        end
    end

    always_comb begin
        for(int i=0; i<NUM_ELEMENTS*2+1; i++)begin
            c_temp_abs[i] = (c_temp[i][WORD_LEN+EXTRA_BIT+1])? ~c_temp[i] + 1: c_temp[i];
            c_temp_0[i] = (c_temp[i][WORD_LEN+EXTRA_BIT+1])?-c_temp_abs[i][WORD_LEN-1:0]: c_temp_abs[i][WORD_LEN-1:0];
            c_temp_1[i] = (c_temp[i][WORD_LEN+EXTRA_BIT+1])?-c_temp_abs[i][WORD_LEN*2-1:WORD_LEN]: c_temp_abs[i][WORD_LEN*2-1:WORD_LEN];
        end
    end

    always_comb begin
        for(int i=0; i<NUM_ELEMENTS*2+1; i++)begin
            if(i==0)begin
                c[i] = c_temp_0[i];
            end 
            else begin
                c[i] = c_temp_0[i] + c_temp_1[i-1];
            end
        end
    end
    


endmodule




