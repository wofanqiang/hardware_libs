module multiplier
#(
    parameter NUM_ELEMENTS          = 17,
    parameter BIT_LEN               = 17,
    parameter WORD_LEN              = 16
)
(
    input logic [BIT_LEN-1:0] A[NUM_ELEMENTS],
    input logic [BIT_LEN-1:0] B[NUM_ELEMENTS],

    output logic [BIT_LEN-1:0] M[NUM_ELEMENTS*2]
);

    localparam EXTRA_BIT = $clog2(NUM_ELEMENTS*2);
    localparam GRID_PP_BIT = WORD_LEN + 2 + EXTRA_BIT;
    
    logic[BIT_LEN*2-1:0]  pp[NUM_ELEMENTS][NUM_ELEMENTS];

   genvar i,j;
	generate 
	    for(i = 0; i < NUM_ELEMENTS; i++)begin:mul_array_row
	        for(j = 0; j < NUM_ELEMENTS; j++)begin:mul_array_col
	                dsp_multiplier #(.A_BIT_LEN(BIT_LEN), 
                                     .B_BIT_LEN(BIT_LEN)) 
                    u_mul_multiplier(
                                .A(A[j][BIT_LEN-1:0]),
                                .B(B[i][BIT_LEN-1:0]),
                                .P(pp[j][i])
                                );
	        end
	    end
	endgenerate

	localparam MUL_OUT_BIT_LEN = 2*BIT_LEN;
	localparam PAD_ZERO_LONG = GRID_PP_BIT - WORD_LEN;
    localparam PAD_ZERO_SHORT = GRID_PP_BIT - WORD_LEN - 2;


    logic[GRID_PP_BIT-1:0]  grid_pp[NUM_ELEMENTS*2][NUM_ELEMENTS*2];

    always_comb begin
        for(int c = 0; c < NUM_ELEMENTS*2; c++)begin:grid_pp_col
	        for(int r = 0; r < NUM_ELEMENTS*2; r++)begin:grid_pp_row
                grid_pp[c][r] = 0;
            end
        end

        for(int i = 0; i < NUM_ELEMENTS; i++)begin:grid_pp_set_value_row
	        for(int j = 0; j < NUM_ELEMENTS; j++)begin:grid_pp_set_value_col
                //grid_pp[j+i][i] = {{(EXTRA_BIT){1'b0}}, pp[j+i][i]};
				grid_pp[j+i][2*i] = {{(PAD_ZERO_LONG){1'b0}}, pp[j][i][WORD_LEN-1:0]};
				grid_pp[j+i+1][2*i+1] = {{(PAD_ZERO_SHORT){1'b0}}, pp[j][i][MUL_OUT_BIT_LEN-1:WORD_LEN]};
	        end
	    end
    end

    


   	logic [GRID_PP_BIT-1:0]  mid_sum[NUM_ELEMENTS*2];

   	genvar gi;
   	generate
      // The first and last columns have only one entry, return in S
      	always_comb begin 
      	   	mid_sum[0][GRID_PP_BIT-1:0]                  = grid_pp[0][0][GRID_PP_BIT-1:0];
          	mid_sum[(NUM_ELEMENTS*2)-1][GRID_PP_BIT-1:0] = grid_pp[(NUM_ELEMENTS*2)-1][(NUM_ELEMENTS*2)-1][GRID_PP_BIT-1:0];
      	end
    
        for (gi=1; gi<(NUM_ELEMENTS*2)-1; gi=gi+1) begin : col_sums
          	localparam integer CUR_ELEMENTS = (gi <  NUM_ELEMENTS) ? (2*gi+1) : 2*(NUM_ELEMENTS*2 - gi) -1;
          	localparam integer GRID_INDEX   = (gi <  NUM_ELEMENTS) ? 0 : ((gi - NUM_ELEMENTS)*2+1);
    
          	adder_tree_2_to_1 #(.NUM_ELEMENTS(CUR_ELEMENTS),
                                    .BIT_LEN(GRID_PP_BIT)
                                   )
             	adder_tree_2_to_1 (
                 .terms(grid_pp[gi][GRID_INDEX:(GRID_INDEX + CUR_ELEMENTS - 1)]),
                 .S(mid_sum[gi])
              );
    
        end
   	endgenerate


	always_comb begin
		M[0] = {1'b0, mid_sum[0][WORD_LEN-1:0]};
        for (int i = 1; i < NUM_ELEMENTS*2; i++) begin:S_temp_col
            M[i] = mid_sum[i][WORD_LEN-1:0] + mid_sum[i-1][GRID_PP_BIT-1:WORD_LEN];
        end
    end
    


endmodule



module dsp_multiplier
   #(
    parameter int A_BIT_LEN       = 17,
    parameter int B_BIT_LEN       = 17,
    parameter int MUL_OUT_BIT_LEN = A_BIT_LEN + B_BIT_LEN
    )
   (
    input  logic [A_BIT_LEN-1:0]       A,
    input  logic [B_BIT_LEN-1:0]       B,
    output logic [MUL_OUT_BIT_LEN-1:0] P
   );

    always_comb begin
        P[MUL_OUT_BIT_LEN-1:0] = A[A_BIT_LEN-1:0] * B[B_BIT_LEN-1:0];
    end
endmodule

module adder_tree_2_to_1
   #(
    parameter int NUM_ELEMENTS      = 9,
    parameter int BIT_LEN           = 16
    )
   (
    input  logic [BIT_LEN-1:0] terms[NUM_ELEMENTS],
    output logic [BIT_LEN-1:0] S
   );


   generate
      	if (NUM_ELEMENTS == 1) begin // Return value
      	  	always_comb begin
      	  	   S[BIT_LEN-1:0] = terms[0];
      	  	end
      	end else if (NUM_ELEMENTS == 2) begin // Return value
      	   	always_comb begin
      	   	   S[BIT_LEN-1:0] = terms[0] + terms[1];
      	   	end
      	end else begin
      	   	localparam integer NUM_RESULTS = integer'(NUM_ELEMENTS/2) + (NUM_ELEMENTS%2);
      	   	logic [BIT_LEN-1:0] next_level_terms[NUM_RESULTS];

      	   	adder_tree_level #(.NUM_ELEMENTS(NUM_ELEMENTS),
      	   	                   .BIT_LEN(BIT_LEN)
      	   	) adder_tree_level (
      	   	                   .terms(terms),
      	   	                   .results(next_level_terms)
      	   	);

      	   	adder_tree_2_to_1 #(.NUM_ELEMENTS(NUM_RESULTS),
      	   	                         .BIT_LEN(BIT_LEN)
      	   	) adder_tree_2_to_1 (
      	   	                         .terms(next_level_terms),
      	   	                         .S(S)
      	   	);
      	end
   endgenerate
endmodule


module adder_tree_level
   #(
    parameter int NUM_ELEMENTS = 3,
    parameter int BIT_LEN      = 19,
    parameter int NUM_RESULTS  = integer'(NUM_ELEMENTS/2) + (NUM_ELEMENTS%2)
    )
   (
    input  logic [BIT_LEN-1:0] terms[NUM_ELEMENTS],
    output logic [BIT_LEN-1:0] results[NUM_RESULTS]
   );

   	always_comb begin
      	for (int i=0; i<(NUM_ELEMENTS / 2); i++) begin
      	   results[i] = terms[i*2] + terms[i*2+1];
      	end

      	if( NUM_ELEMENTS % 2 == 1 ) begin
      	   results[NUM_RESULTS-1] = terms[NUM_ELEMENTS-1];
      	end
   	end
endmodule