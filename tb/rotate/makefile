# =========================
# 基本配置
# =========================
TOP     = tb
# 保持你原始的文件名 rotate.sv，并手动添加同目录下的 ram.sv
RTL     = ../../rtl/ram.sv \
          ../../rtl/rotate.sv

TB      = tb_rotate.sv

VCS     = vcs
SIMV    = simv

# debug & 波形
VCS_FLAGS = -full64 -sverilog -debug_access+all -kdbs
VCS_FLAGS += +v2k
VCS_FLAGS += -timescale=1ns/1ps

# =========================
# 编译
# =========================
all: compile

# 编译时会将 ram.sv 和 rotate.sv 一起编译
compile:
	$(VCS) $(VCS_FLAGS) $(RTL) $(TB) -o $(SIMV)

# =========================
# 运行 (你关心的运行指令在这里)
# =========================
sim:
	./$(SIMV)

# =========================
# 波形（DVE）
# =========================
wave:
	./$(SIMV) -gui &

# =========================
# 清理
# =========================
clean:
	rm -rf csrc $(SIMV) $(SIMV).daidir ucli.key DVEfiles *.vpd *.log