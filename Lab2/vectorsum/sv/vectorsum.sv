
module vectorsum 
#(  parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter VECTOR_SIZE = 1024)
(
    input  logic                  clock,
    input  logic                  reset,
    input  logic                  start,
    output logic                  done,
    input  logic [DATA_WIDTH-1:0] x_dout,
    output logic [ADDR_WIDTH-1:0] x_addr,
    input  logic [DATA_WIDTH-1:0] y_dout,
    output logic [ADDR_WIDTH-1:0] y_addr,
    output logic [DATA_WIDTH-1:0] z_din,
    output logic [ADDR_WIDTH-1:0] z_addr,
    output logic                  z_wr_en
);

typedef enum logic [1:0] {s0, s1, s2} state_t;
state_t state, state_c;
logic [ADDR_WIDTH-1:0] i, i_c;
logic done_c, done_o;

assign done <= done_o;

always_ff @(posedge clock or posedge reset) begin
    if (reset) begin
        state <= s0;
        done_o <= 1'b0;
        i <= '0;
    end else begin
        state <= state_c;
        done_o  <= done_c;
        i <= i_c;
    end
end

always_comb begin
    z_din   = 'b0;
    z_wr_en = 'b0;
    z_addr  = 'b0;
    x_addr  = 'b0;
    y_addr  = 'b0;

    state_c = state;
    i_c     = i;
    done_c  = done_o;

    case (state)
        s0: begin
            i_c = '0;
            if (start == 1'b1) begin
                state_c = s1;
                done_c  = 1'b0;
            end else begin
                state_c = s0;
            end
        end

        s1: begin
            if ($unsigned(i) < $unsigned(VECTOR_SIZE)) begin
                x_addr  = i;
                y_addr  = i;
                state_c = s2;
            end else begin
                done_c  = 1'b1;
                state_c = s0;
            end
        end

        s2: begin
            z_din = $signed(y_dout) + $signed(x_dout);
            z_addr = i;
            z_wr_en = 1'b1;
            i_c = i + 'b1;
            state_c = s1;
        end

        default: begin
            z_din   = 'x;
            z_wr_en = 'x;
            z_addr  = 'x;
            x_addr  = 'x;
            y_addr  = 'x;
            state_c = s0;
            i_c     = 'x;
            done_c  = 'x;
        end
    endcase
end

endmodule