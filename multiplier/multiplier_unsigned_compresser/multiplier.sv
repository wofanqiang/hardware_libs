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


    logic [BIT_LEN-1:0] A_reg[NUM_ELEMENTS];
    logic [BIT_LEN-1:0] B_reg[NUM_ELEMENTS];

    localparam EXTRA_BIT = $clog2(NUM_ELEMENTS);
    localparam GRID_PP_BIT = BIT_LEN*2 + EXTRA_BIT;
    
    logic[BIT_LEN*2-1:0]  pp[NUM_ELEMENTS*2][NUM_ELEMENTS];

    genvar i,j;
	generate 
	    for(i = 0; i < NUM_ELEMENTS; i++)begin:mul_array_row
	        for(j = 0; j < NUM_ELEMENTS; j++)begin:mul_array_col
	                dsp_multiplier #(.A_BIT_LEN(BIT_LEN), 
                                     .B_BIT_LEN(BIT_LEN)) 
                    u_mul_multiplier(
                                .A(A[i][BIT_LEN-1:0]),
                                .B(B[j][BIT_LEN-1:0]),
                                .P(pp[j+i][i])
                                );
	        end
	    end
	endgenerate

    //整理部分积矩阵，列队齐
    logic[GRID_PP_BIT-1:0]  grid_pp[NUM_ELEMENTS*2][NUM_ELEMENTS];

    always_comb begin
        for(int c = 0; c < NUM_ELEMENTS*2; c++)begin:grid_pp_col
	        for(int r = 0; r < NUM_ELEMENTS; r++)begin:grid_pp_row
                grid_pp[c][r] = 0;
            end
        end

        for(int i = 0; i < NUM_ELEMENTS; i++)begin:grid_pp_set_value_row
	        for(int j = 0; j < NUM_ELEMENTS; j++)begin:grid_pp_set_value_col
                grid_pp[j+i][i] = {{(EXTRA_BIT){1'b0}}, pp[j+i][i]};
	        end
	    end
    end

    logic[GRID_PP_BIT-1:0]  pp_c[NUM_ELEMENTS*2];
    logic[GRID_PP_BIT-1:0]  pp_s[NUM_ELEMENTS*2];


    //以列为单位进行3:2压缩。
    genvar gp_i;
    generate
        for(gp_i=0; gp_i<NUM_ELEMENTS*2; gp_i++)begin:grid_pp_compressor_tree_col
            compressor_tree_3_to_2
                #(.NUM_ELEMENTS(NUM_ELEMENTS), .BIT_LEN(GRID_PP_BIT))
                u_compressor_tree_3_to_2_grid_pp
                (
                    .terms(grid_pp[gp_i]),
                    .C(pp_c[gp_i]),
                    .S(pp_s[gp_i])
                );
        end
    endgenerate


    logic[GRID_PP_BIT-1:0]  M_temp[NUM_ELEMENTS*2];


    always_comb begin
        for (int i = 0; i < NUM_ELEMENTS*2; i++) begin
            M_temp[i] = pp_c[i] + pp_s[i];
        end
    end   

    always_comb begin
        M[0] = M_temp[0][WORD_LEN-1:0];
        M[1] = M_temp[1][WORD_LEN-1:0] + M_temp[0][WORD_LEN*2-1:WORD_LEN];
        M[NUM_ELEMENTS*2-1] = M_temp[NUM_ELEMENTS*2-1][BIT_LEN-1:0] + M_temp[NUM_ELEMENTS*2-2][WORD_LEN*2-1:WORD_LEN] + M_temp[NUM_ELEMENTS*2-3][GRID_PP_BIT-1:WORD_LEN*2];
        for (int i = 2; i < NUM_ELEMENTS*2-1; i++) begin
            M[i] = M_temp[i][WORD_LEN-1:0] + M_temp[i-1][WORD_LEN*2-1:WORD_LEN] + M_temp[i-2][GRID_PP_BIT-1:WORD_LEN*2];
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

module carry_save_adder_tree_level
   #(
     parameter int NUM_ELEMENTS = 3,
     parameter int BIT_LEN      = 19,

     parameter int NUM_RESULTS  = (integer'(NUM_ELEMENTS/3) * 2) + 
                                   (NUM_ELEMENTS%3)
    )
   (
    input  logic [BIT_LEN-1:0] terms[NUM_ELEMENTS],
    output logic [BIT_LEN-1:0] results[NUM_RESULTS]
   );

   genvar i;
   generate
      for (i=0; i<(NUM_ELEMENTS / 3); i++) begin : csa_insts
         // Add three consecutive terms 
         carry_save_adder #(.BIT_LEN(BIT_LEN))
            carry_save_adder (
                              .A(terms[i*3]),
                              .B(terms[(i*3)+1]),
                              .Cin(terms[(i*3)+2]),
                              .Cout({results[i*2][0],
                                     results[i*2][BIT_LEN-1:1]}),
                              .S(results[(i*2)+1][BIT_LEN-1:0])
                             );
      end

      // Save any unused terms for the next level 
      for (i=0; i<(NUM_ELEMENTS % 3); i++) begin : csa_level_extras
         always_comb begin
            results[(NUM_RESULTS - 1) - i][BIT_LEN-1:0] = 
               terms[(NUM_ELEMENTS- 1) - i][BIT_LEN-1:0];
         end
      end
   endgenerate
endmodule



module compressor_tree_3_to_2
   #(
    parameter int NUM_ELEMENTS      = 9,
    parameter int BIT_LEN           = 16
    )
   (
    input  logic [BIT_LEN-1:0] terms[NUM_ELEMENTS],
    output logic [BIT_LEN-1:0] C,
    output logic [BIT_LEN-1:0] S
   );

`ifdef FASTSIM
   // This is intended for simulation only to improve compile and run time
    always_comb begin
        C = 0;
        S = 0;
        for(int k = 0; k < NUM_ELEMENTS; k++) begin
             S += terms[k];
        end
    end
   
`else

   // If there is only one or two elements, then return the input (no tree)
   // If there are three elements, this is the last level in the tree
   // For greater than three elements:
   //   Instantiate a set of carry save adders to process this level's terms
   //   Recursive instantiate this module to complete the rest of the tree
    generate
        if (NUM_ELEMENTS == 1) begin // Return value
            always_comb begin
               C[BIT_LEN-1:0] = '0;
               S[BIT_LEN-1:0] = terms[0];
            end
        end
        else if (NUM_ELEMENTS == 2) begin // Return value
            always_comb begin
               C[BIT_LEN-1:0] = terms[1];
               S[BIT_LEN-1:0] = terms[0];
            end
        end
        else if (NUM_ELEMENTS == 3) begin // last level
           /* verilator lint_off UNUSED */
            logic [BIT_LEN-1:0] Cout;
           /* verilator lint_on UNUSED */

            carry_save_adder #(.BIT_LEN(BIT_LEN))
                carry_save_adder (
                                .A(terms[0]),
                                .B(terms[1]),
                                .Cin(terms[2]),
                                .Cout(Cout),
                               .S(S[BIT_LEN-1:0])
                               );
            always_comb begin
               C[BIT_LEN-1:0] = {Cout[BIT_LEN-2:0], 1'b0};
            end
        end
        else begin
           //localparam integer NUM_RESULTS = ($rtoi($floor(NUM_ELEMENTS/3)) * 2) + 
           //                                 (NUM_ELEMENTS%3);
            localparam integer NUM_RESULTS = (integer'(NUM_ELEMENTS/3) * 2) + 
                                             (NUM_ELEMENTS%3);

            logic [BIT_LEN-1:0] next_level_terms[NUM_RESULTS];

            carry_save_adder_tree_level #(.NUM_ELEMENTS(NUM_ELEMENTS),
                                         .BIT_LEN(BIT_LEN)
                                        )
                carry_save_adder_tree_level (
                                           .terms(terms),
                                           .results(next_level_terms)
                                          );

            compressor_tree_3_to_2 #(.NUM_ELEMENTS(NUM_RESULTS),
                                    .BIT_LEN(BIT_LEN)
                                   )
                compressor_tree_3_to_2 (
                                      .terms(next_level_terms),
                                      .C(C),
                                      .S(S)
                                     );
        end
    endgenerate
`endif
endmodule

/*******************************************************************************
  Copyright 2019 Supranational LLC

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*******************************************************************************/

/*    
  A parameterized carry save adder (CSA)
  Loops through each input bit and feeds a full adder (FA)
             --------------------------------
            | CSA                            |
            |         for each i in BIT_LEN  |
            |            -------             |
            |           | FA    |            |
  A[]   --> |  Ai   --> |       | --> Si     | --> S[]
  B[]   --> |  Bi   --> |       |            |
  Cin[] --> |  Cini --> |       | --> Couti  | --> Cout[]
            |            -------             |
             --------------------------------
*/

module carry_save_adder
   #(
    parameter int BIT_LEN = 19
    )
   (
    input  logic [BIT_LEN-1:0] A,
    input  logic [BIT_LEN-1:0] B,
    input  logic [BIT_LEN-1:0] Cin,
    output logic [BIT_LEN-1:0] Cout,
    output logic [BIT_LEN-1:0] S
   );

    genvar i;
    generate
        for (i=0; i<BIT_LEN; i++) begin : csa_fas
            full_adder full_adder(
                                 .A(A[i]),
                                 .B(B[i]),
                                 .Cin(Cin[i]),
                                 .Cout(Cout[i]),
                                 .S(S[i])
                                );
        end
    endgenerate
endmodule



/*******************************************************************************
  Copyright 2019 Supranational LLC

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*******************************************************************************/

/*
  A basic 1-bit full adder
              -------
             | FA    |
    A    --> |       | --> S
    B    --> |       |
    Cin  --> |       | --> Cout
              -------
*/

module full_adder
   (
    input  logic A,
    input  logic B,
    input  logic Cin,
    output logic Cout,
    output logic S
   );

    always_comb begin
       S    =  A ^ B ^ Cin;
       Cout = (A & B) | (Cin & (A ^ B));
    end

	//always_comb begin
    //	case({A,B,Cin})
    //		3'b000 : {Cout, S} = 2'd0;
    //		3'b001 : {Cout, S} = 2'd1;
    //		3'b010 : {Cout, S} = 2'd1;
    //		3'b011 : {Cout, S} = 2'd2;
    //		3'b100 : {Cout, S} = 2'd1;
    //		3'b101 : {Cout, S} = 2'd2;
    //		3'b110 : {Cout, S} = 2'd2;
    //		3'b111 : {Cout, S} = 2'd3;
    //	endcase
	//end
endmodule




