// Code your testbench here
// or browse Examples
// ============================================================
// 4-bit Up-Down Counter - UVM Testbench (Single File)
// Simulator : Aldec Riviera-PRO
// Compile Options : -sv -uvm
// Run Options     : +access+r +UVM_TESTNAME=counter_test
// ============================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

// ============================================================
// INTERFACE
// ============================================================
interface counter_if(input logic clk);
    logic        rst;
    logic        enable;
    logic        up_down;
    logic [3:0]  count;
endinterface

// ============================================================
// SEQUENCE ITEM (Transaction)
// ============================================================
class counter_seq_item extends uvm_sequence_item;

    `uvm_object_utils(counter_seq_item)

    // Stimulus fields
    rand logic enable;
    rand logic up_down;
         logic rst;

    // Response fields
    logic [3:0] count;

    // Constraints
    constraint enable_dist {
        enable dist {1 := 80, 0 := 20};
    }

    constraint updown_dist {
        up_down dist {1 := 50, 0 := 50};
    }

    function new(string name = "counter_seq_item");
        super.new(name);
    endfunction

    // For printing transaction details
    function string convert2string();
        return $sformatf("rst=%0b enable=%0b up_down=%0b count=%0d",
                          rst, enable, up_down, count);
    endfunction

endclass

// ============================================================
// SEQUENCE (Random)
// ============================================================
class counter_rand_seq extends uvm_sequence #(counter_seq_item);

    `uvm_object_utils(counter_rand_seq)

    int unsigned num_transactions = 500;

    function new(string name = "counter_rand_seq");
        super.new(name);
    endfunction

    	task body();
    		counter_seq_item tr;
    // ✅ Add reset wait at start of sequence body
    		#30; // wait for reset to finish (rst=1 for 20ns + margin)
    
    		repeat(num_transactions) begin
        		tr = counter_seq_item::type_id::create("tr");
        		start_item(tr);
        		assert(tr.randomize()) else
            	`uvm_fatal("SEQ", "Randomization failed")
        		finish_item(tr);
    		end

    	endtask

endclass

// ============================================================
// DRIVER
// ============================================================
class counter_driver extends uvm_driver #(counter_seq_item);

    `uvm_component_utils(counter_driver)

    virtual counter_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual counter_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "Could not get virtual interface from config db")
    endfunction

    task run_phase(uvm_phase phase);
        counter_seq_item tr;
        forever begin
            seq_item_port.get_next_item(tr);
            @(negedge vif.clk);
            vif.enable  <= tr.enable;
            vif.up_down <= tr.up_down;
            `uvm_info("DRV", $sformatf("Driving: %s", tr.convert2string()), UVM_HIGH)
            seq_item_port.item_done();
        end
    endtask

endclass

// ============================================================
// MONITOR
// ============================================================
class counter_monitor extends uvm_monitor;

    `uvm_component_utils(counter_monitor)

    virtual counter_if vif;

    // Analysis port to send transactions to scoreboard
    uvm_analysis_port #(counter_seq_item) mon_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon_ap = new("mon_ap", this);
        if (!uvm_config_db #(virtual counter_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON", "Could not get virtual interface from config db")
    endfunction

    task run_phase(uvm_phase phase);
        counter_seq_item tr;
        forever begin
            @(posedge vif.clk);
            tr = counter_seq_item::type_id::create("tr");
            tr.enable  = vif.enable;
            tr.up_down = vif.up_down;
            tr.rst     = vif.rst;
            tr.count   = vif.count;
            `uvm_info("MON", $sformatf("Observed: %s", tr.convert2string()), UVM_HIGH)
            mon_ap.write(tr);
        end
    endtask

endclass

// ============================================================
// SCOREBOARD
// ============================================================
class counter_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(counter_scoreboard)

    // Analysis export to receive transactions from monitor
    uvm_analysis_imp #(counter_seq_item, counter_scoreboard) sb_imp;

    logic [3:0] expected;
    int pass_count;
    int fail_count;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        expected   = 0;
        pass_count = 0;
        fail_count = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sb_imp = new("sb_imp", this);
    endfunction

    // Called automatically when monitor writes to analysis port
    function void write(counter_seq_item tr);

        // Compare first
        if (!tr.rst) begin
            if (tr.count !== expected) begin
                `uvm_error("SB", $sformatf("MISMATCH! Expected=%0d Got=%0d | %s",
                            expected, tr.count, tr.convert2string()))
                fail_count++;
            end else begin
                `uvm_info("SB", $sformatf("PASS Expected=%0d Got=%0d",
                           expected, tr.count), UVM_MEDIUM)
                pass_count++;
            end
        end

        // Update reference model AFTER compare
        if (tr.rst)
            expected = 0;
        else if (tr.enable) begin
            if (tr.up_down)
                expected = expected + 1;
            else
                expected = expected - 1;
        end

    endfunction

    // Print summary at end of simulation
    function void report_phase(uvm_phase phase);
        `uvm_info("SB", $sformatf("-----------------------------"),         UVM_NONE)
        `uvm_info("SB", $sformatf("SCOREBOARD SUMMARY"),                    UVM_NONE)
        `uvm_info("SB", $sformatf("Total PASS = %0d", pass_count),          UVM_NONE)
        `uvm_info("SB", $sformatf("Total FAIL = %0d", fail_count),          UVM_NONE)
        `uvm_info("SB", $sformatf("-----------------------------"),          UVM_NONE)
        if (fail_count == 0)
            `uvm_info("SB", "*** ALL TESTS PASSED ***",  UVM_NONE)
        else
            `uvm_error("SB", "*** TESTS FAILED ***")
    endfunction

endclass

// ============================================================
// AGENT
// ============================================================
class counter_agent extends uvm_agent;

    `uvm_component_utils(counter_agent)

    counter_driver                    drv;
    counter_monitor                   mon;
    uvm_sequencer #(counter_seq_item) seqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv  = counter_driver::type_id::create("drv", this);
        mon  = counter_monitor::type_id::create("mon", this);
        seqr = uvm_sequencer #(counter_seq_item)::type_id::create("seqr", this);
    endfunction

    // Connect driver to sequencer
    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction

endclass

// ============================================================
// ENVIRONMENT
// ============================================================
class counter_env extends uvm_env;

    `uvm_component_utils(counter_env)

    counter_agent      agent;
    counter_scoreboard sb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = counter_agent::type_id::create("agent", this);
        sb    = counter_scoreboard::type_id::create("sb",  this);
    endfunction

    // Connect monitor analysis port to scoreboard
    function void connect_phase(uvm_phase phase);
        agent.mon.mon_ap.connect(sb.sb_imp);
    endfunction

endclass

// ============================================================
// TEST
// ============================================================
class counter_test extends uvm_test;

    `uvm_component_utils(counter_test)

    counter_env      env;
    counter_rand_seq rand_seq;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = counter_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        rand_seq = counter_rand_seq::type_id::create("rand_seq");

        phase.raise_objection(this);

        `uvm_info("TEST", "Starting random sequence", UVM_NONE)
        rand_seq.num_transactions = 500;
        rand_seq.start(env.agent.seqr);
        `uvm_info("TEST", "Sequence complete", UVM_NONE)

        #200; // Allow final transactions to complete
        phase.drop_objection(this);
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info("TEST", "UVM Test Complete", UVM_NONE)
    endfunction

endclass

// ============================================================
// TOP MODULE
// ============================================================
module tb;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    logic clk;
    always #5 clk = ~clk;

    counter_if vif(clk);

    up_down_counter dut (
        .clk     (clk),
        .rst     (vif.rst),
        .enable  (vif.enable),
        .up_down (vif.up_down),
        .count   (vif.count)
    );

    // SVA Assertions
    property reset_check;
        @(posedge clk) vif.rst |-> (vif.count == 0);
    endproperty
    assert property(reset_check)
        else $error("ASSERTION FAILED: Reset check");

    property enable_check;
        @(posedge clk) (!vif.enable && !vif.rst) |=> $stable(vif.count);
    endproperty
    assert property(enable_check)
        else $error("ASSERTION FAILED: Enable check");

    property count_up_check;
        @(posedge clk) (vif.enable && vif.up_down && !vif.rst && vif.count != 15)
            |=> (vif.count == ($past(vif.count) + 1));
    endproperty
    assert property(count_up_check)
        else $error("ASSERTION FAILED: Count up check");

    property count_down_check;
        @(posedge clk) (vif.enable && !vif.up_down && !vif.rst && vif.count != 0)
            |=> (vif.count == ($past(vif.count) - 1));
    endproperty
    assert property(count_down_check)
        else $error("ASSERTION FAILED: Count down check");

    property wrap_up_check;
        @(posedge clk) (vif.enable && vif.up_down && !vif.rst && vif.count == 15)
            |=> (vif.count == 0);
    endproperty
    assert property(wrap_up_check)
        else $error("ASSERTION FAILED: Wrap up check");

    property wrap_down_check;
        @(posedge clk) (vif.enable && !vif.up_down && !vif.rst && vif.count == 0)
            |=> (vif.count == 15);
    endproperty
    assert property(wrap_down_check)
        else $error("ASSERTION FAILED: Wrap down check");

    // Functional Coverage
    covergroup counter_cg @(posedge clk);
        cp_enable  : coverpoint vif.enable;
        cp_updown  : coverpoint vif.up_down;
        cp_count   : coverpoint vif.count {
            bins all_states[] = {[0:15]};
            bins wrap_up      = (15 => 0);
            bins wrap_down    = (0  => 15);
        }
        cross cp_enable, cp_updown;
    endgroup

    counter_cg cg1 = new();
// ✅ Block 1 - run_test() MUST be at time 0
	initial begin
    	uvm_config_db #(virtual counter_if)::set(null, "uvm_test_top.*", "vif", vif);
    	run_test("counter_test");  // called at time 0
	end

// ✅ Block 2 - reset control separate
	initial begin
    	clk     = 0;
    	vif.rst = 1;
    	#20;
    	vif.rst = 0;
	end
    final begin
        $display("-------------------------------");
        $display("Functional Coverage = %0.2f %%", cg1.get_coverage());
        $display("Enable  coverage    = %0.2f %%", cg1.cp_enable.get_coverage());
        $display("UpDown  coverage    = %0.2f %%", cg1.cp_updown.get_coverage());
        $display("Count   coverage    = %0.2f %%", cg1.cp_count.get_coverage());
        $display("-------------------------------");
    end
    initial 
        // Pass virtual interface to UVM config db
     begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb);
        #12000;
        $finish;
    end

endmodule