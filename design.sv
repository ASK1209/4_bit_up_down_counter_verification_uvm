// Code your design here
module up_down_counter (
    input  logic clk,
    input  logic rst,
    input  logic enable,
    input  logic up_down,
    output logic [3:0] count
);

always_ff @(posedge clk or posedge rst) begin
    if (rst)
        count <= 0;
    else if (enable) begin
        if (up_down)
            count <= count + 1;
        else
            count <= count - 1;
    end
end

endmodule