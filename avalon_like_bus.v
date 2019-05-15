//translator:definition0---------------------------------------------------------------------------
	//outputs to slave
read_i,
write_i,
chipselect_i,
data_i,
address_i,
flush_i, 
	//inputs from slave
irq_o,
readyfordata_o,
dataavailable_o,
endofpocket_o,
slaveid_o,
data_o,
address_o,
hold_t,
wait_t,
//translator:definition1---------------------------------------------------------------------------
	//outputs to slave
input read_i,
input write_i,
input chipselect_i,
input [(16-1):0] data_i,
input [(32-1):0] address_i,
input flush_i, 
	//inputs from slave
output irq_o,
output readyfordata_o,
output dataavailable_o,
output endofpocket_o,
output [4:0] slaveid_o,
output [16-1:0] data_o,
output [32-1:0] address_o,
output [4-1:0] hold_t,
output [4-1:0] wait_t,
//translator:definition2---------------------------------------------------------------------------
	//outputs to slave
input read_i;
input write_i;
input chipselect_i;
input [(16-1):0] data_i;
input [(32-1):0] address_i;
input flush_i; 
	//inputs from slave
output irq_o;
output readyfordata_o;
output dataavailable_o;
output endofpocket_o;
output [4:0] slaveid_o;
output [16-1:0] data_o;
output [32-1:0] address_o;
output [4-1:0] hold_t;
output [4-1:0] wait_t;
//-------------------------------------------------------------------------------------------------
//new bus------------------------------------------------------------------------------------------
parameter   NABS                = 10;
parameter   NPOCKKEPT           = 16;
parameter   SSWH                = 4;
parameter   SABS                = 5;
parameter   SADDR               = 32;
parameter   SDATA               = 16;
parameter	SPAR				= 8;
parameter	TIMEOUT				= 200;
localparam  maxid               = ID_SENSOR;
wire  [NABS:0] 		read_i;
wire  [NABS:0] 		write_i;
wire  [NABS:0] 		chipselect_i;
wire [(SDATA-1):0] 	data_i		    [NABS:0];
wire [(SADDR-1):0] 	address_i		[NABS:0];
wire [(NABS):0] 	flush_i;        
wire [NABS:0] 		irq_o;
wire [NABS:0] 		readyfordata_o;
wire [NABS:0] 		dataavailable_o;
wire [NABS:0] 		endofpocket_o;
wire [(SABS-1):0] 	slaveid_o		[NABS:0];
wire [(SDATA-1):0] 	data_o			[NABS:0];
wire [(SADDR-1):0] 	address_o		[NABS:0];
wire [SSWH-1:0] 	hold_t			[NABS:0];
wire [SSWH-1:0] 	wait_t			[NABS:0];
reg  [SDATA-1:0]	mem				[NPOCKKEPT-1:0];
// var 2
reg                 CHIPSEL;
wire                REAL_READ;
reg  [SABS-1:0]		ID_MASTER;
wire [SABS-1:0] 	ID_SLAVE;
wire [SABS-1:0] 	ID_SENDER;
wire [SABS-1:0] 	ID_RECIEVER;
reg  [SPAR-1:0]		WRITE_COUNT;
reg  [SPAR-1:0]		WRITE_WAIT_COUNT;
wire [SPAR-1:0]     WRITE_WAIT_TIME;
reg  [SPAR-1:0]		READ_COUNT;
reg  [SPAR-1:0]		READ_WAIT_COUNT;
wire [SPAR-1:0]     READ_WAIT_TIME;
reg  [SPAR-1:0]		TOTAL_WRITE;
reg  [SPAR-1:0]		TOTAL_READ;
wire [SPAR-1:0]		TOTAL;
reg                 WRITE_READ;
reg                 EOP;
reg  [SADDR-1:0]    ADDRESS;
reg  [2:0]          WRITE_STATE;
reg  [2:0]          READ_STATE;
reg                 ARBITRAGE_STATE;
wire                VALID_READ;
wire                VALID_WRITE;
wire                VALID;
reg  [SPAR-1:0]     MEMORY_WRITE_COUNT;
reg  [SPAR-1:0]     MEMORY_READ_COUNT;
reg  [SPAR-1:0]     TIMEOUT_COUNT;
wire                TIMEOUT_FLAG;
//useful defines
assign      REAL_READ       = |READ_STATE;
assign      TOTAL           = (WRITE_READ) ? TOTAL_READ : TOTAL_WRITE;
assign      ID_SLAVE        = (slaveid_o[ID_MASTER] > maxid) ? ID_Flash : slaveid_o[ID_MASTER];
assign      ID_SENDER 		= (WRITE_READ) ? ID_MASTER : ID_SLAVE;
assign      ID_RECIEVER 	= (WRITE_READ) ? ID_SLAVE : ID_MASTER;
assign      READ_WAIT_TIME  = (WRITE_READ) ? 0 : wait_t[ID_SLAVE];
assign      WRITE_WAIT_TIME = hold_t[ID_RECIEVER];
assign      VALID_READ      = ((WRITE_READ) ? dataavailable_o[ID_MASTER] : 1)&TIMEOUT_FLAG&(MEMORY_READ_COUNT < NPOCKKEPT);
assign      VALID_WRITE     = ((WRITE_READ) ? 1 :  readyfordata_o[ID_MASTER])&TIMEOUT_FLAG;
assign      VALID           = irq_o[ID_MASTER]&(dataavailable_o[ID_MASTER] | readyfordata_o[ID_MASTER]);
assign      TIMEOUT_FLAG    = TIMEOUT_COUNT < TIMEOUT;
localparam  READ_IDLE       = 2'b00;
localparam  READ_MAKE       = 2'b01;
localparam  READ_WAIT       = 2'b10;
localparam  WRITE_IDLE      = 2'b00;
localparam  WRITE_MAKE      = 2'b01;
localparam  WRITE_WAIT      = 2'b10;
localparam  ARBITRAGE_IDLE  = 1'b0;
localparam  ARBITRAGE_HOLD  = 1'b1;
//arbitrage
genvar fi;
for(fi = 0; fi < (NABS+1); fi = fi + 1)
begin : flushes
    assign flush_i[fi] = (ID_MASTER == fi) ? ~TIMEOUT_FLAG : 0;
end
always @(posedge clk25 or negedge rst)
begin : arbitrage
//addresses
	if(rst)
	begin
        case(ARBITRAGE_STATE)
        ARBITRAGE_IDLE :
            begin
                if(VALID)
                begin
                    TIMEOUT_COUNT <= {(SPAR){1'b0}};
                    MEMORY_WRITE_COUNT <= {(SPAR){1'b0}};
                    MEMORY_READ_COUNT <= {(SPAR){1'b0}};
                    CHIPSEL <= 1'b1;
                    EOP <= endofpocket_o[ID_MASTER];
                    WRITE_READ <= dataavailable_o[ID_MASTER];
                    ADDRESS <= address_o[ID_MASTER];
                    ARBITRAGE_STATE <= ARBITRAGE_HOLD;
                end
                else begin
                    ID_MASTER <= (ID_MASTER < NABS) ? ID_MASTER + 1'b1 : {{(SABS-1){1'b0}}, 1'b1};
                end
            end
        ARBITRAGE_HOLD :
            begin
                if((WRITE_COUNT == TOTAL)&(EOP&(TOTAL > 0) | ~TIMEOUT_FLAG)&(WRITE_STATE == WRITE_IDLE)&(WRITE_STATE == WRITE_IDLE))
                begin
                    EOP <= 1'b0;
                    ID_MASTER <= (ID_MASTER < NABS) ? ID_MASTER + 1'b1 : {{(SABS-1){1'b0}}, 1'b1};
                    CHIPSEL <= 1'b0;
                    ADDRESS <= {(SADDR){1'b0}};
                    TIMEOUT_COUNT <= {(SPAR){1'b0}};
                    ARBITRAGE_STATE <= ARBITRAGE_IDLE;
                end
                else begin
                    if(~EOP)
                    begin
                        EOP <= endofpocket_o[ID_MASTER];
                    end
                    if((READ_STATE == READ_MAKE)&VALID_READ)
                    begin
                        if(MEMORY_READ_COUNT < (NPOCKKEPT - 1'b1))
                        begin
                            MEMORY_READ_COUNT <= MEMORY_READ_COUNT + 1'b1;
                        end
                        else begin
                            MEMORY_READ_COUNT <= {(SPAR){1'b0}};
                        end
                    end
                    if((WRITE_STATE == WRITE_WAIT)&~(WRITE_WAIT_COUNT < WRITE_WAIT_TIME)&VALID_WRITE)
                    begin
                        if(MEMORY_WRITE_COUNT < (NPOCKKEPT - 1'b1))
                        begin
                            MEMORY_WRITE_COUNT <= MEMORY_WRITE_COUNT + 1'b1;
                        end
                        else begin
                            MEMORY_WRITE_COUNT <= {(SPAR){1'b0}};
                        end
                    end
                    if(WRITE_READ)
                    begin
                        if(|READ_STATE&~VALID_READ)
                        begin
                            TIMEOUT_COUNT <= TIMEOUT_COUNT + 1'b1;
                        end
                    end
                    else begin
                        if(|WRITE_STATE&~VALID_WRITE)
                        begin
                            TIMEOUT_COUNT <= TIMEOUT_COUNT + 1'b1;
                        end
                    end
                end
            end
        endcase
	end
	else begin
        ARBITRAGE_STATE <= 1'b0;
        CHIPSEL <= 1'b0;
        ID_MASTER <= {{(SABS-1){1'b0}}, 1'b1};
        ADDRESS <= {(SDATA){1'b0}};
        WRITE_READ <= 1'b0;
        EOP <= 1'b0;
        MEMORY_WRITE_COUNT <= {(SPAR){1'b0}};
        MEMORY_READ_COUNT <= {(SPAR){1'b0}};
        TIMEOUT_COUNT <= {(SPAR){1'b0}};
	end
end
genvar ai;
for(ai = 0; ai < (NABS+1); ai = ai + 1)
begin : addresses
    assign chipselect_i[ai] = (ID_SLAVE == ai) ? CHIPSEL : 1'b0;
    assign address_i[ai]    = (ID_SLAVE == ai) ? ((WRITE_READ) ? ADDRESS + WRITE_COUNT : ADDRESS + READ_COUNT) : 1'b0;
end
//write
always @(posedge clk25 or negedge rst)
begin : writecontr
    if(rst)
    begin
        case(WRITE_STATE)
        WRITE_IDLE : 
            begin
                if(ARBITRAGE_STATE == ARBITRAGE_IDLE)
                begin
                    TOTAL_WRITE <= {(SPAR){1'b0}};
                    WRITE_COUNT <= {(SPAR){1'b0}};
                end
                else begin
                    if(TOTAL_WRITE == {(SPAR){1'b0}})
                    begin
                        TOTAL_WRITE <= {{(SPAR-1){1'b0}}, 1'b1};
                    end
                    if(VALID_WRITE&(WRITE_COUNT < READ_COUNT))
                    begin
                        WRITE_STATE <= WRITE_MAKE;
                    end
                end
            end
        WRITE_MAKE :
            begin
                if(VALID_WRITE)
                begin
                    WRITE_WAIT_COUNT <= {(SPAR){1'b0}};
                    WRITE_STATE <= WRITE_WAIT;
                end
                else begin
                    WRITE_STATE <= WRITE_IDLE;
                end
            end
        WRITE_WAIT :
            begin
                if(WRITE_WAIT_COUNT < WRITE_WAIT_TIME)
                begin
                    if(VALID_WRITE)
                    begin
                        WRITE_WAIT_COUNT <= WRITE_WAIT_COUNT + 1'b1;
                    end
                    else begin
                        WRITE_STATE <= WRITE_IDLE;
                    end
                end
                else begin
                    if(~EOP)
                    begin
                        TOTAL_WRITE <= TOTAL_WRITE + 1'b1;
                    end
                    WRITE_COUNT <= WRITE_COUNT + 1'b1;
                    if(WRITE_COUNT < (READ_COUNT - 1'b1))
                    begin
                        WRITE_STATE <= WRITE_MAKE;
                    end
                    else begin
                        WRITE_STATE <= WRITE_IDLE;
                    end
                end
            end
        endcase
    end
    else begin
        TOTAL_WRITE <= {(SPAR){1'b0}};
        WRITE_STATE <= {(SPAR){1'b0}};
        WRITE_COUNT <= {(SPAR){1'b0}};
        WRITE_WAIT_COUNT <= {(SPAR){1'b0}};
    end
end
genvar wi;
for(wi = 0; wi < (NABS+1); wi = wi + 1'b1)
begin : writing
    assign write_i[wi] = (wi == ID_RECIEVER) ? |WRITE_STATE : 1'b0;
    assign data_i[wi]  = ((wi == ID_RECIEVER)&write_i[wi]) ? mem[MEMORY_WRITE_COUNT] : 1'b0;
end
//read
integer mi;
always @(posedge clk25 or negedge rst)
begin : readcontr
    if(rst)
    begin
        case(READ_STATE)
        READ_IDLE :
            begin
                if(ARBITRAGE_STATE == ARBITRAGE_IDLE)
                begin
                    TOTAL_READ <= {(SPAR){1'b0}};
                    READ_COUNT <= {(SPAR){1'b0}};
                end
                else begin
                    if(TOTAL == {(SPAR){1'b0}})
                    begin
                        TOTAL_READ <= {{(SPAR-1){1'b0}}, 1'b1};
                    end
                    if(VALID_READ&(READ_COUNT < TOTAL))
                    begin
                        READ_WAIT_COUNT <= {(SPAR){1'b0}};
                        READ_STATE <= (WRITE_READ) ? READ_MAKE : READ_WAIT;
                    end
                end
            end
        READ_WAIT :
            begin
                if(VALID_READ)
                begin
                    if(READ_WAIT_COUNT < READ_WAIT_TIME)
                    begin
                        READ_WAIT_COUNT <= READ_WAIT_COUNT + 1'b1;
                    end
                    else begin
                        READ_STATE <= READ_MAKE;
                    end
                end
                else begin
                    READ_STATE <= READ_IDLE;
                end
            end
        READ_MAKE :
            begin
                if(VALID_READ)
                begin
                    mem[MEMORY_READ_COUNT] <= data_o[ID_SENDER];
                    READ_COUNT <= READ_COUNT + 1'b1;
                    if(~EOP)
                    begin
                        TOTAL_READ <= TOTAL_READ + 1'b1;
                    end
                    if(READ_COUNT < (TOTAL - 1'b1))
                    begin
                        READ_WAIT_COUNT <= {(SPAR){1'b0}};
                        READ_STATE <= READ_WAIT;
                    end
                    else begin
                        READ_STATE <= READ_IDLE;
                    end
                end
                else begin
                    READ_STATE <= READ_IDLE;
                end
            end
        endcase
    end
    else begin
		for(mi = 0; mi < NPOCKKEPT; mi = mi + 1)
		begin
			mem[mi] <= 0;
		end
        TOTAL_READ <= {(SPAR){1'b0}};
        READ_STATE <= {(SPAR){1'b0}};
        READ_COUNT <= {(SPAR){1'b0}};
        READ_WAIT_COUNT <= {(SPAR){1'b0}};
    end
end
genvar ri;
for(ri = 0; ri < (NABS+1); ri = ri + 1'b1)
begin : reading
    assign read_i[ri] = (ri == ID_SENDER) ? REAL_READ : 1'b0;
end
//
assign data_o[0] = (chipselect_i[0]&readyfordata_o[ID_MASTER]) ? mem[ADDRESS] : {(SDATA){1'b0}};
assign address_o[0] =  {(SADDR){1'b0}};
assign dataavailable_o[0] = 1'b0;
assign readyfordata_o[0] = 1'b0;
assign irq_o[0] = 1'b0;
assign endofpocket_o[0] = 1'b0;
assign slaveid_o[0] =  {(4){1'b0}};
assign hold_t[0] = {(SPAR){1'b0}};
assign wait_t[0] = {(SPAR){1'b0}};
//bus:end------------------------------------------------------------------------------------------
//inbus:definition---------------------------------------------------------------------------------
.read_i(read_i[ID_CTI]),
.write_i(write_i[ID_CTI]),
.chipselect_i(chipselect_i[ID_CTI]),
.data_i(data_i[ID_CTI]),
.address_i(address_i[ID_CTI]),
.flush_i(flush_i[ID_CTI]),
.irq_o(irq_o[ID_CTI]),
.readyfordata_o(readyfordata_o[ID_CTI]),
.dataavailable_o(dataavailable_o[ID_CTI]),
.endofpocket_o(endofpocket_o[ID_CTI]),
.slaveid_o(slaveid_o[ID_CTI]),
.data_o(data_o[ID_CTI]),
.address_o(address_o[ID_CTI]),
.hold_t(hold_t[ID_CTI]),
.wait_t(wait_t[ID_CTI]),
//-------------------------------------------------------------------------------------------------
