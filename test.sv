`ifndef FSDB_DEPTH
`define FSDB_DEPTH 0
`endif

typedef struct {
    string opcode;
    string dst_s;
    string rs1_s;
    string rs2_s;
    int    dst;
    int    rs1;
    int    rs2;
    int    imul;
    int    sew;
} instruction_t;


class vsi_mem_model #(
    int RegWidth = 32
);

    typedef logic   [8-1:0]             ByteType    ;
    typedef logic   [RegWidth-1:0]      RegType     ;
    typedef logic   [RegWidth/8-1:0]    StrobType   ;
    typedef longint unsigned            AddrType    ;

    static ByteType mem [AddrType];

    static function void WriteReg(
        AddrType    addr    ,
        RegType     data    ,
        StrobType   strob
    );
        //$display("%s(%0d) @ %0t: WriteReg, addr=%x, data=%x, strob=%b", `__FILE__, `__LINE__, $time, addr, data, strob);
        foreach (strob[offset]) begin
            if (strob[offset] == 'b1) begin
                mem[addr+offset] = data[8*offset+:8];
            end
        end
    endfunction: WriteReg

    static function RegType ReadReg(
        AddrType    addr
    );
        RegType data    ;
        foreach (data[bit_index]) begin
            if (bit_index%8 == 0) begin
                if (mem.exists(addr+(bit_index/8))) begin
                    data[bit_index+:8] = mem[addr+(bit_index/8)];
                end else begin
                    data[bit_index+:8] = 'hxx;
                end
            end
        end
        //$display("%s(%0d) @ %0t: ReadReg, addr=%x, data=%x", `__FILE__, `__LINE__, $time, addr, data);
        return data;
    endfunction:ReadReg
    
endclass

class vsi_broadcast #(
    type    BD_TYPE =   int
);

    static BD_TYPE  item;

endclass //vsi_broadcast

interface vsi_if #(
  parameter VSI_RD_NUM = 8,
  parameter VSI_WR_NUM = 4
)(
    input logic clk     ,
    input logic rst_n
);

    logic   [32-1:0]    vsi_op      ;
    logic               vsi_lmul    ;
    logic               vsi_sew     ;
    logic               rdy         ;
    logic               vld         ;
    logic               idle        ;

    logic   [VSI_RD_NUM-1:0][  4:0] vsi_rf_raddr;
    logic   [VSI_RD_NUM-1:0][127:0] vsi_rf_rdata;
    logic   [VSI_WR_NUM-1:0][  4:0] vsi_rf_waddr;
    logic   [VSI_WR_NUM-1:0][ 15:0] vsi_rf_wstrb;
    logic   [VSI_WR_NUM-1:0][127:0] vsi_rf_wdata;

    clocking cb@(posedge clk);
      default input #1 output #1;
      output  vsi_op;
      output  vsi_lmul;
      output  vsi_sew;
      output  rdy;
      input   vld;
      input   idle;
    endclocking

    task DoReset();
        vsi_op      =   'bx;
        vsi_lmul    =   'bx;
        vsi_sew     =   'bx;
        rdy         =   'b0;
    endtask: DoReset

    task SendOpCode(
        logic   [32-1:0]    op      ,
        logic               lmul    ,
        logic               sew     
    );
        @(cb iff (rst_n === 'b1));
        cb.rdy         <= 'b1      ;
        cb.vsi_op      <=  op      ;
        cb.vsi_lmul    <=  lmul    ;
        cb.vsi_sew     <=  sew     ;
        @(cb iff (
            //(cb.rdy    === 'b1)    &&
            (cb.vld    === 'b1)
        ))
        cb.vsi_op      <=  'bx ;
        cb.vsi_lmul    <=  'bx ;
        cb.vsi_sew     <=  'bx ;
        cb.rdy         <=  'b0 ;
    endtask: SendOpCode
    
endinterface //vsi_if

class vsi_agent #(
  parameter VSI_RD_NUM = 2,
  parameter VSI_WR_NUM = 1
);
  virtual vsi_if vif;
  bit [33:0] op_queue[$];
  int check_pass_cnt, check_fail_cnt, check_cnt;

  function new(string name = "vsi_agent"); 
    check_cnt = 0;
    check_pass_cnt = 0;
    check_fail_cnt = 0;
  endfunction : new

  task drive_vif();
    forever begin
	bit [33:0] tr; // pop last
	wait(op_queue.size>0);
	tr = op_queue.pop_front(); // pop last
        vif.rdy      <= 'b1;
        vif.vsi_op   <= tr[33:2];
        vif.vsi_lmul <= tr[1];
        vif.vsi_sew  <= tr[0];
	@(posedge vif.clk iff (vif.vld === 1 && vif.rdy === 1));
	vif.rdy      <= 'b0;
        vif.vsi_op   <= 'bx;
        vif.vsi_lmul <= 'bx;
        vif.vsi_sew  <= 'bx;
    end
  endtask : drive_vif

  function string trim_string(string s);
    int i, j;
    i = 0;
    j = s.len() - 1;
  
    while ((i <= j) && (s[i] == " " || s[i] == "\t")) i++;
  
    while ((j >= i) && (s[j] == " " || s[j] == "\t")) j--;
  
    return s.substr(i, j);
  endfunction

  function int str_find_1st(string str, string delimiter, int start_idx);
    foreach(str[ii]) begin
      if(ii>=start_idx) begin
        if(string'(str[ii]) == delimiter)
           return ii;
      end
    end
    return -1;
  endfunction

  function void split_string(string str, string delimiter, ref string tokens[$]);
    int start, delim_idx;
    string token;
    tokens = {};
    start = 0;
    while ((delim_idx = str_find_1st(str, delimiter, start)) != -1) begin
      token = str.substr(start, delim_idx - 1);
      tokens.push_back(trim_string(token));
      start = delim_idx + delimiter.len();
    end
    if (start < str.len())
      tokens.push_back(trim_string(str.substr(start)));
  endfunction

  task wait_idle();
    @(vif.cb);
    while (top.dut.vsi_cop_idle==0) begin
      @(vif.cb);
    end
    repeat(100) @(vif.cb);
  endtask : wait_idle

  task parse_sequence();
    int           f_cmdin, f_result;
    int           inst, test_seq;
    instruction_t inst_t;
    bit [127:0]   temp_reg_mdl, temp_reg_dut;
    int           inst_cnt=0;

    if(!$value$plusargs("test_seq=%0d", test_seq)) test_seq=0;
    f_cmdin = $fopen($sformatf("/data/share/src/check_sequence/check_sequence%0d.txt", test_seq), "r");
    f_result = $fopen($sformatf("/data/share/src/check_sequence/result_%0d.txt", test_seq), "r");
    if (!(f_cmdin)) $display("\033[1;31mERROR\033[0m: can not open check_sequence file");
    else $display("INFO: Start of file check_sequence%0d.txt", test_seq);
    if (!(f_result)) $display("\033[1;31mERROR\033[0m: can not open result file");

    while (!$feof(f_cmdin)) begin
      string        line, line_result, token, tokens[$];
      int           result1, result2;
      result1 = $fgets(line,f_cmdin);
      if (!result1) begin
        $display("INFO: End of file check_sequence%0d.txt", test_seq);
      end else begin
        split_string(line, ",", tokens);

        inst_t.opcode = tokens[0];
        inst_t.dst_s  = tokens[1];
        inst_t.rs1_s  = tokens[2];
        inst_t.rs2_s  = tokens[3];
        void'($sscanf(tokens[4], "%d", inst_t.imul));
        void'($sscanf(tokens[5], "%d", inst_t.sew));
        inst_cnt += 1;
        
        $display("Parsed instruction (line %0d): ", inst_cnt);
        $display("  opcode = %s", inst_t.opcode);
        $display("  dst    = %s", inst_t.dst_s);
        $display("  vs2    = %s", inst_t.rs1_s); // rs1 is vs2
        $display("  vs1    = %s", inst_t.rs2_s); // rs2 is vs1/uimm
        $display("  imul   = %0d", inst_t.imul);
        $display("  sew    = %0d", inst_t.sew);

        if (inst_t.opcode == "vslideup.vi") begin
          void'($sscanf(inst_t.dst_s, "v%d", inst_t.dst));
          void'($sscanf(inst_t.rs1_s, "v%d", inst_t.rs1)); 
          void'($sscanf(inst_t.rs2_s, "%d", inst_t.rs2));  // rs2 is uimm
        end else if ((inst_t.opcode != "randomize_vrf")||(inst_t.opcode != "check_point")) begin
          void'($sscanf(inst_t.dst_s, "v%d", inst_t.dst));
          void'($sscanf(inst_t.rs1_s, "v%d", inst_t.rs1));
          void'($sscanf(inst_t.rs2_s, "v%d", inst_t.rs2));
        end
        case (inst_t.opcode)
          "randomize_vrf": 
            begin
              result2 = $fgets(line_result,f_result);
              if (line_result=="random_vrf\n") begin
                for(longint addr=0; addr<32; addr++) begin
                  result2 = $fgets(line_result,f_result);
                  void'($sscanf(line_result, "0x%h\n", temp_reg_mdl));
                  $display($sformatf("Randomize memory: addr=v%0d, data=0x%32x", addr, temp_reg_mdl));
                  vsi_mem_model#(128)::WriteReg(addr*16, temp_reg_mdl, 16'hffff);
                end
              end else begin
                $display($sformatf("\033[1;31mERROR\033[0m: something wrong with random_vrf [%s]", line_result));
              end
            end
          "vxor.vv":
            begin
              inst = {7'b0010111, inst_t.rs1[4:0], inst_t.rs2[4:0], 3'b000, inst_t.dst[4:0], 7'b1010111};
//              vif.SendOpCode(inst[31:0], inst_t.imul[0], inst_t.sew[0]);
              op_queue.push_back({inst[31:0], inst_t.imul[0], inst_t.sew[0]});
            end
          "vmacc.vv":
            begin
              inst = {7'b1011011, inst_t.rs1[4:0], inst_t.rs2[4:0], 3'b010, inst_t.dst[4:0], 7'b1010111};
//              vif.SendOpCode(inst[31:0], inst_t.imul[0], inst_t.sew[0]);
              op_queue.push_back({inst[31:0], inst_t.imul[0], inst_t.sew[0]});
            end
          "vredsum.vs":
            begin
              inst = {7'b0000001, inst_t.rs1[4:0], inst_t.rs2[4:0], 3'b010, inst_t.dst[4:0], 7'b1010111};
//              vif.SendOpCode(inst[31:0], inst_t.imul[0], inst_t.sew[0]);
              op_queue.push_back({inst[31:0], inst_t.imul[0], inst_t.sew[0]});
            end
          "vslideup.vi":
            begin
              inst = {7'b0011101, inst_t.rs1[4:0], inst_t.rs2[4:0], 3'b011, inst_t.dst[4:0], 7'b1010111};
//              vif.SendOpCode(inst[31:0], inst_t.imul[0], inst_t.sew[0]);
              op_queue.push_back({inst[31:0], inst_t.imul[0], inst_t.sew[0]});
            end
          "vrgather.vv":
            begin
              inst = {7'b0011001, inst_t.rs1[4:0], inst_t.rs2[4:0], 3'b000, inst_t.dst[4:0], 7'b1010111};
//              vif.SendOpCode(inst[31:0], inst_t.imul[0], inst_t.sew[0]);
              op_queue.push_back({inst[31:0], inst_t.imul[0], inst_t.sew[0]});
            end
          "check_point":
            begin
              result2 = $fgets(line_result,f_result);
              wait_idle();
              if (line_result==$sformatf("check_point_%0d\n", check_cnt)) begin
                for(longint addr=0; addr<32; addr++) begin
                  result2 = $fgets(line_result,f_result);
                  void'($sscanf(line_result, "0x%h\n", temp_reg_mdl));
                  temp_reg_dut = vsi_mem_model#(128)::ReadReg(addr*16);
                  if (temp_reg_mdl === temp_reg_dut) begin
                    $display($sformatf("\033[1;32mCHECK PASS\033[0m: addr=V%0d dut=0x%32x mdl=0x%32x", addr, temp_reg_dut, temp_reg_mdl));
                    check_pass_cnt += 1;
                  end else begin
                    $display($sformatf("\033[1;31mCHECK FAIL\033[0m: addr=V%0d dut=0x%32x mdl=0x%32x", addr, temp_reg_dut, temp_reg_mdl));
                    check_fail_cnt += 1;
                  end
                end
              end else begin
                $display($sformatf("\033[1;31mERROR\033[0m: something wrong with check_point_%0d [%s]", check_cnt, line_result));
              end
              check_cnt += 1;
            end
          default: 
            begin
              $display($sformatf("\033[1;33mWARNING\033[0m: unsupport opcode: %s", inst_t.opcode));
            end
        endcase
      end
    end
  endtask

endclass : vsi_agent

`define vsi_rf_forbid(seq) assert property (@(posedge clk) disable iff (~rst_n) not (strong(seq)))

module rf_model(
  clk,
  rst_n,
  vsi_rf_raddr, 
  vsi_rf_rdata,  
  vsi_rf_waddr, 
  vsi_rf_wdata,  
  vsi_rf_wstrb
);  

// number of read port of VRF
    localparam VSI_RD_NUM = 8;
// number of write port of VRF
    localparam VSI_WR_NUM = 4;
// VRF index width
    localparam REG_INDEX_W = 5;
// VRF depth
    localparam NUM_VRF   = 32;
// vector length
    localparam VLEN      = 128;
// vector length/byte
    localparam VLENB     = VLEN/8;

// global signal
    input                                       clk;
    input                                       rst_n;

// read channel 
    input   logic   [VSI_RD_NUM-1:0][REG_INDEX_W-1:0]     vsi_rf_raddr;   // register index for read
    output  logic   [VSI_RD_NUM-1:0][VLEN-1:0]            vsi_rf_rdata;   // readout data

// write channel    
    input   logic   [VSI_WR_NUM-1:0][REG_INDEX_W-1:0]     vsi_rf_waddr;   // register index for write
    input   logic   [VSI_WR_NUM-1:0][VLEN-1:0]            vsi_rf_wdata;   // write data
    input   logic   [VSI_WR_NUM-1:0][VLENB-1:0]           vsi_rf_wstrb;   // write enable for each byte. 

//
// code start
//
  always @(posedge clk) begin
        for (int i=0; i<VSI_WR_NUM; i++) begin
            if (vsi_rf_wstrb[i] != 'b0) begin
                vsi_mem_model#(128)::WriteReg(vsi_rf_waddr[i]*16,vsi_rf_wdata[i],vsi_rf_wstrb[i]);
            end
        end
    end
  genvar i;
  generate
    for (i=0; i<VSI_RD_NUM; i++) begin
        initial begin
            forever begin
                #1;
                vsi_rf_rdata[i]= vsi_mem_model#(128)::ReadReg(vsi_rf_raddr[i]*16);
            end
        end
    end
  endgenerate

//
// assertion
//
// report errors when WAW Hazard occurs
  wire waddr1_eq_waddr0 = vsi_rf_waddr[1] == vsi_rf_waddr[0];
  wire wstrb1_eq_wstrb0 = |(vsi_rf_wstrb[1] & vsi_rf_wstrb[0]);
  WAW_VSI_RF_WADDR1: `vsi_rf_forbid(waddr1_eq_waddr0 && wstrb1_eq_wstrb0)
    else $error("WAW Hazard: vsi_rf_waddr[1] would overwrite a register");

  wire waddr2_eq_waddr0 = vsi_rf_waddr[2] == vsi_rf_waddr[0];
  wire wstrb2_eq_wstrb0 = |(vsi_rf_wstrb[2] & vsi_rf_wstrb[0]);
  wire waddr2_eq_waddr1 = vsi_rf_waddr[2] == vsi_rf_waddr[1];
  wire wstrb2_eq_wstrb1 = |(vsi_rf_wstrb[2] & vsi_rf_wstrb[1]);
  WAW_VSI_RF_WADDR2: `vsi_rf_forbid((waddr2_eq_waddr0 && wstrb2_eq_wstrb0) ||
                                     (waddr2_eq_waddr1 && wstrb2_eq_wstrb1) )
    else $error("WAW Hazard: vsi_rf_waddr[2] would overwrite a register");

  wire waddr3_eq_waddr0 = vsi_rf_waddr[3] == vsi_rf_waddr[0];
  wire wstrb3_eq_wstrb0 = |(vsi_rf_wstrb[3] & vsi_rf_wstrb[0]);
  wire waddr3_eq_waddr1 = vsi_rf_waddr[3] == vsi_rf_waddr[1];
  wire wstrb3_eq_wstrb1 = |(vsi_rf_wstrb[3] & vsi_rf_wstrb[1]);
  wire waddr3_eq_waddr2 = vsi_rf_waddr[3] == vsi_rf_waddr[2];
  wire wstrb3_eq_wstrb2 = |(vsi_rf_wstrb[3] & vsi_rf_wstrb[2]);
  WAW_VSI_RF_WADDR3: `vsi_rf_forbid((waddr3_eq_waddr0 && wstrb3_eq_wstrb0) ||
                                     (waddr3_eq_waddr1 && wstrb3_eq_wstrb1) ||
                                     (waddr3_eq_waddr2 && wstrb3_eq_wstrb2) )
    else $error("WAW Hazard: vsi_rf_waddr[3] would overwrite a register");

endmodule

module top();
  logic         clk;
  logic         rst_n;
  int           idle_cnt = 0, busy_cnt = 0, run_time = 0;
  int           busy_cycle = 0, perf_start = 0, perf_end = 0;
  int           sequence_done = 0;
  
  localparam VSI_RD_NUM = 8;
  localparam VSI_WR_NUM = 4;  
  
  vsi_if #(.VSI_RD_NUM(VSI_RD_NUM), 
           .VSI_WR_NUM(VSI_WR_NUM)) vif  (
    .clk    (clk    ),
    .rst_n  (rst_n  )
  );

  // Instance DUT here

  initial begin   //  Clock Gen
    clk = 'b0;
    forever begin
      #10;
      clk = !clk;
    end
  end

  initial begin   // Reset Gen
    rst_n = 'b0;
    vif.DoReset();
    #201;    // A-Sync reset
    rst_n = 'b1;
  end

  initial begin   //Send VIF to tb
    vsi_broadcast#(virtual vsi_if)::item = vif;
  end

  initial begin   // parse sequence and drive vif
    vsi_agent #(VSI_RD_NUM, VSI_WR_NUM) m_agent = new();
    m_agent.vif = vif;
    repeat(500) @(posedge clk);
    $display("INFO: start parsing instruction");
    fork
      m_agent.drive_vif();
    join_none
    m_agent.parse_sequence();
    sequence_done = 1;
    $display("INFO: end of parsing instruction");
    $display("INFO: totol check cnt = %0d", m_agent.check_cnt);
    $display("INFO: totol pass cnt  = %0d", m_agent.check_pass_cnt);
    $display("INFO: totol fail cnt  = %0d", m_agent.check_fail_cnt);
  end

  //module instance
  vector_cop #(.VSI_RD_NUM(VSI_RD_NUM), 
               .VSI_WR_NUM(VSI_WR_NUM))  dut(
    .vsi_clk          (clk          ),
    .vsi_rst_n        (rst_n        ),

    .vsi_op           (vif.vsi_op   ),
    .vsi_lmul         (vif.vsi_lmul ),
    .vsi_sew          (vif.vsi_sew  ),
    .vsi_op_valid     (vif.rdy      ),
    .vsi_op_ready     (vif.vld      ),

    .vsi_cop_idle   (vif.idle     ),

    .vsi_rf_raddr   (vif.vsi_rf_raddr),
    .vsi_rf_rdata   (vif.vsi_rf_rdata),
    .vsi_rf_waddr   (vif.vsi_rf_waddr),
    .vsi_rf_wstrb   (vif.vsi_rf_wstrb),
    .vsi_rf_wdata   (vif.vsi_rf_wdata)
  );

  rf_model u_rf_model_inst(
    .clk            (clk                ),
    .rst_n          (rst_n              ),

    .vsi_rf_raddr     (vif.vsi_rf_raddr),
    .vsi_rf_rdata     (vif.vsi_rf_rdata),
    .vsi_rf_waddr     (vif.vsi_rf_waddr),
    .vsi_rf_wstrb     (vif.vsi_rf_wstrb),
    .vsi_rf_wdata     (vif.vsi_rf_wdata)
  );

  initial begin
    $fsdbAutoSwitchDumpfile(2048,"dump.fsdb",1000);
    $fsdbDumpvars(`FSDB_DEPTH,top);
    $fsdbDumpMDA;
    $fsdbDumpon();
    $display("FSDB_DEPTH =%0d",`FSDB_DEPTH);
  end

  initial begin
    forever begin
      repeat(10000) @(posedge clk);
      $fsdbDumpflush;
      $display("simulation time still go @%d", $time());
    end
  end

  initial begin  // check hang
    forever begin
      @(posedge clk);
      busy_cnt ++;
      run_time ++;
      if(vif.idle==0) busy_cycle ++;
      if(sequence_done==1) idle_cnt ++;

      if(vif.idle==1) busy_cnt = 0;
      if(vif.idle==0) idle_cnt = 0;
      if(busy_cnt > 100000) begin
        $display("\033[1;31mERROR\033[0m: timeout, busy_cnt>100000");
        $finish();
      end
      if(idle_cnt > 2000) begin
        $display("INFO: check idle_cnt>2000");
        $display("============VSI 2025================");
        $display("INFO: Simulation finish");
        $display("INFO: totol work cycle = %0d", perf_end-perf_start);
        $display("INFO: busy cycle       = %0d", busy_cycle);
        $display("============VSI 2025================");
        $finish();
      end
      if(run_time > 1000000) begin
        $display("\033[1;31mERROR\033[0m: timeout, run_time>10000000");
        $finish();
      end
      // perf
      if(perf_start == 0 && vif.vld==1 && vif.rdy==1) perf_start = run_time;
      if(vif.idle==0) perf_end = run_time;
    end
  end
endmodule