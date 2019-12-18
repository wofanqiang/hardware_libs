//~ `New testbench

module tb_multiplier;      

// test Parameters
parameter PERIOD  = 10;

parameter NUM_ELEMENTS          = 17;
parameter BIT_LEN               = 17;
parameter WORD_LEN              = 16;

// test Inputs
logic signed [BIT_LEN:0] a[NUM_ELEMENTS];
logic signed [BIT_LEN:0] b[NUM_ELEMENTS];

logic signed [WORD_LEN*NUM_ELEMENTS+2:0] a_p;
logic signed [WORD_LEN*NUM_ELEMENTS+2:0] b_p;

// test Outputs
logic signed [BIT_LEN:0] c[NUM_ELEMENTS*2+1];
logic signed [WORD_LEN*(NUM_ELEMENTS*2+1):0] c_except;
logic signed [WORD_LEN*(NUM_ELEMENTS*2+1):0] c_actual;


always_comb begin
    for(int i=0; i<NUM_ELEMENTS; i++)begin
        if(i==0)begin
            a_p = a[i];
            b_p = b[i];
        end
        else begin
            a_p = a_p + a[i]*(2**(16*i));
            b_p = b_p + b[i]*(2**(16*i));
        end
    end
end

assign c_except = a_p * b_p;


always_comb begin
    for(int i=0; i<NUM_ELEMENTS*2+1; i++)begin
        if(i==0)begin
            c_actual = c[i];
        end
        else begin
            c_actual = c_actual + c[i]*(2**(16*i));
        end
    end
end


initial
begin
    for(int i=0; i<NUM_ELEMENTS; i++)begin
        a[i] <= 0;
        b[i] <= 0;
    end
    #(PERIOD*2);
    repeat(100) begin
        for(int j=0; j<NUM_ELEMENTS; j++)begin
            a[j] <= {$random}[17:0] - {$random}[17:0];
            b[j] <= {$random}[17:0] - {$random}[17:0];
            //a[i] <= (2**17-1);
            //b[i] <= -(2**17-1);
        end

        #(PERIOD*2);
        if(c_except == c_actual)begin
            $display("Correct!\nc_actual = %h\nc_except = %h\n\n", c_actual,c_except);
        end
        else begin
            $display("Error!\nc_actual = %h\nc_except = %h\nc_except - c_actual = %h\n\n", c_actual,c_except, c_except - c_actual);
        end
        #(PERIOD*2);
    end
    #(PERIOD*2);
    $stop;
end


multiplier 
#(
    .NUM_ELEMENTS ( NUM_ELEMENTS ),
    .BIT_LEN      ( BIT_LEN      ),
    .WORD_LEN     ( WORD_LEN     ))
 u_multiplier_256 (
    .a(a),
    .b(b),
    .c(c)
);


endmodule