#! /usr/bin/env perl
# This program is released under the Common Public License V1.0
#
# You should have received a copy of Common Public License V1.0 along with
# with this program.
#
# Author(s): Patrick Steuer <patrick.steuer@de.ibm.com>
#
# Copyright IBM Corp. 2018

use strict;
use FindBin qw($Bin);
use lib "$Bin";
use perlasm::s390x qw(:DEFAULT :VX :VXE :VXD AUTOLOAD LABEL VERBATIM);	# XXX DEBUG VX
#use perlasm::s390x qw(:DEFAULT AUTOLOAD LABEL);	# XXX DEBUG VX

my $zero="%r0";
my $sp="%r15";

PERLASM_BEGIN($ARGV[0]);

TEXT	();

# int ica_mp_mul512(uint64_t *r, const uint64_t *a, const uint64_t *b);
{
my @A=map("%v$_",(0..4));
my @B=map("%v$_",(5..7,16,17));
my @t=map("%v$_",(18..30));
my $vzero="%v31";

my ($r,$a,$b,$c1,$c2,$c3)=map("%r$_",(2..4,1,5,8));

GLOBL	("ica_mp_mul512");
TYPE	("ica_mp_mul512","\@function");
ALIGN	(16);
LABEL	("ica_mp_mul512");
	larl	("%r1","facility_bits");
	lg	("%r0","16(%r1)");
	tmhh	("%r0",0x300);			# check for vector enhancement
	jz	(".Lmul512_novx");		# and packed decimal facilities

VERBATIM("#if !defined(__s390x__) && !defined(__s390x)\n");
	std	("%f4","16*4+2*8($sp)");
	std	("%f6","16*4+3*8($sp)");
VERBATIM("#endif\n");

	larl	("%r1",".Lconst");

	vzero	($vzero);
	vlm	(@t[0],@t[3],"0($b)");
	vlm	(@t[4],@t[8],"0(%r1)");
	vgbm	(@t[9],0x7f7f);

	# load b (base 2^64 -> base 2^56)
	vperm	(@B[0],@t[0],$vzero,@t[4]);	# B1B0
	vperm	(@B[1],@t[1],@t[0],@t[5]);	# B3B2
	vperm	(@B[2],@t[2],@t[1],@t[6]);	# B5B4
	vperm	(@B[3],@t[3],@t[2],@t[7]);	# B7B6
	vperm	(@B[4],$vzero,@t[3],@t[8]);	# B9B8
	vn	(@B[1],@B[1],@t[9]);
	vn	(@B[2],@B[2],@t[9]);
	vn	(@B[3],@B[3],@t[9]);

	vlm	(@t[0],@t[3],"0($a)");

	vpdi	(@t[4],@t[4],@t[4],4);
	vpdi	(@t[5],@t[5],@t[5],4);
	vpdi	(@t[6],@t[6],@t[6],4);
	vpdi	(@t[7],@t[7],@t[7],4);
	vpdi	(@t[8],@t[8],@t[8],4);

	# load a (base 2^64 -> base 2^56)
	vperm	(@A[0],@t[0],$vzero,@t[4]);	# A0A1
	vperm	(@A[1],@t[1],@t[0],@t[5]);	# A2A3
	vperm	(@A[2],@t[2],@t[1],@t[6]);	# A4A5
	vperm	(@A[3],@t[3],@t[2],@t[7]);	# A6A7
	vperm	(@A[4],$vzero,@t[3],@t[8]);	# A8A9

	vmrhg	(@t[0],$vzero,@A[0]);		# 00A0 XXX

	vn	(@A[1],@A[1],@t[9]);
	vn	(@A[2],@A[2],@t[9]);
	vn	(@A[3],@A[3],@t[9]);

	# r = a * b (base 2^56)
	vmslg	(@t[1],@B[0],@t[0],$vzero,0);	# B100+B0A0
	vmslg	(@t[2],@B[0],@A[0],$vzero,0);	# B1A0+B0A1
	vmslg	(@t[3],@B[1],@t[0],$vzero,0);	# B300+B2A0
	vmslg	(@t[4],@B[0],@A[1],$vzero,0);	# B1A2+B0A3
	vmslg	(@t[5],@B[2],@t[0],$vzero,0);	# B500+B4A0
	vmslg	(@t[6],@B[0],@A[2],$vzero,0);	# B1A4+B0A5
	vmslg	(@t[7],@B[3],@t[0],$vzero,0);	# B700+B6A0
	vmslg	(@t[8],@B[0],@A[3],$vzero,0);	# B1A6+B0A7
	vmslg	(@t[9],@B[4],@t[0],$vzero,0);	# B900+B8A0, free t[0]
	 vsldb	(@t[0],@A[0],@A[1],8);		# A1A2 XXX
	vmslg	(@t[10],@B[0],@A[4],$vzero,0);	# B1A8+B0A9

	 vstrl	(@t[1],"1($r)",6);
	 vsldb	(@t[1],$vzero,@t[1],9);
	vmslg	(@t[3],@B[0],@t[0],@t[3],0);	# B1A1+B0A2
	vmslg	(@t[4],@B[1],@A[0],@t[4],0);	# B3A0+B2A1
	vmslg	(@t[5],@B[1],@t[0],@t[5],0);	# B3A1+B2A2
	 vaq	(@t[2],@t[2],@t[1]);		# free t[1]
	vmslg	(@t[6],@B[1],@A[1],@t[6],0);	# B3A2+B2A3
	vmslg	(@t[7],@B[2],@t[0],@t[7],0);	# B5A1+B4A2
	vmslg	(@t[8],@B[1],@A[2],@t[8],0);	# B3A4+B2A5
	 vsteb	(@t[2],"0($r)",15);
	 vsteb	(@t[2],"8+7($r)",14);
	 vsteh	(@t[2],"8+5($r)",6);
	 vsteh	(@t[2],"8+3($r)",5);
	 vsteb	(@t[2],"8+2($r)",9);
	 vsldb	(@t[2],$vzero,@t[2],9);
	vmslg	(@t[9],@B[3],@t[0],@t[9],0);	# B7A1+B6A2
	vmslg	(@t[10],@B[1],@A[3],@t[10],0);	# B3A6+B2A7
	vmslg	(@t[1],@B[4],@t[0],$vzero,0);	# B9A1+B8A2, free t[0]
	 vaq	(@t[3],@t[3],@t[2]);		# free t[2]
	 vsldb	(@t[0],@A[1],@A[2],8);		# A3A4 XXX
	vmslg	(@t[2],@B[1],@A[4],$vzero,0);	# B3A8+B2A9

	vmslg	(@t[5],@B[0],@t[0],@t[5],0);	# B1A3+B0A4
	 vsteh	(@t[3],"8($r)",7);
	 vsteh	(@t[3],"16+6($r)",6);
	 vsteh	(@t[3],"16+4($r)",5);
	 vsteb	(@t[3],"16+3($r)",9);
	 vsldb	(@t[3],$vzero,@t[3],9);
	vmslg	(@t[6],@B[2],@A[0],@t[6],0);	# B5A0+B4A1
	vmslg	(@t[7],@B[1],@t[0],@t[7],0);	# B3A3+B2A4
	vmslg	(@t[8],@B[2],@A[1],@t[8],0);	# B5A2+B4A3
	 vaq	(@t[4],@t[4],@t[3]);		# free t[3]
	vmslg	(@t[9],@B[2],@t[0],@t[9],0);	# B5A3+B4A4
	vmslg	(@t[10],@B[2],@A[2],@t[10],0);	# B5A4+B4A5
	vmslg	(@t[1],@B[3],@t[0],@t[1],0);	# B7A3+B6A4
	 vsteh	(@t[4],"16+1($r)",7);
	 vsteb	(@t[4],"16($r)",13);
	 vsteb	(@t[4],"24+7($r)",12);
	 vsteh	(@t[4],"24+5($r)",5);
	 vsteb	(@t[4],"24+4($r)",9);
	 vsldb	(@t[4],$vzero,@t[4],9);
	vmslg	(@t[2],@B[2],@A[3],@t[2],0);	# B5A6+B4A7
	vmslg	(@t[3],@B[4],@t[0],$vzero,0);	# B9A3+B8A4, free t[0]
	 vsldb	(@t[0],@A[2],@A[3],8);		# A5A6 XXX
	 vaq	(@t[5],@t[5],@t[4]);		# fee t[4]
	vmslg	(@t[4],@B[2],@A[4],$vzero,0);	# B5A8+B4A9

	vmslg	(@t[7],@B[0],@t[0],@t[7],0);	# B1A5+B0A6
	vmslg	(@t[8],@B[3],@A[0],@t[8],0);	# B7A0+B6A1
	 vstef	(@t[5],"24($r)",3);
	 vsteh	(@t[5],"32+6($r)",5);
	 vsteb	(@t[5],"32+5($r)",9);
	 vsldb	(@t[5],$vzero,@t[5],9);
	vmslg	(@t[9],@B[1],@t[0],@t[9],0);	# B3A5+B2A6
	vmslg	(@t[10],@B[3],@A[1],@t[10],0);	# B7A2+B6A3
	vmslg	(@t[1],@B[2],@t[0],@t[1],0);	# B5A5+B4A6
	 vaq	(@t[6],@t[6],@t[5]);		# free t[5]
	vmslg	(@t[2],@B[3],@A[2],@t[2],0);	# B7A4+B6A5
	vmslg	(@t[3],@B[3],@t[0],@t[3],0);	# B7A5+B6A6
	vmslg	(@t[4],@B[3],@A[3],@t[4],0);	# B7A6+B6A7
	 vstef	(@t[6],"32+1($r)",3);
	 vsteb	(@t[6],"32($r)",11);
	 vsteb	(@t[6],"40+7($r)",10);
	 vsteb	(@t[6],"40+6($r)",9);
	 vsldb	(@t[6],$vzero,@t[6],9);
	vmslg	(@t[5],@B[4],@t[0],$vzero,0);	# B9A5+B8A6, free t[0]
	 vsldb	(@t[0],@A[3],@A[4],8);		# A7A8 XXX
	vmslg	(@t[11],@B[3],@A[4],$vzero,0);	# B7A8+B6A9

	 vaq	(@t[7],@t[7],@t[6]);		# free t[6]
	vmslg	(@t[9],@B[0],@t[0],@t[9],0);	# B1A7+B0A8
	vmslg	(@t[10],@B[4],@A[0],@t[10],0);	# B9A0+B8A1
	vmslg	(@t[1],@B[1],@t[0],@t[1],0);	# B3A7+B2A8
	 vstef	(@t[7],"40+2($r)",3);
	 vsteh	(@t[7],"40($r)",5);
	 vsteb	(@t[7],"48+7($r)",9);
	 vsldb	(@t[7],$vzero,@t[7],9);
	vmslg	(@t[2],@B[4],@A[1],@t[2],0);	# B9A2+B8A3
	vmslg	(@t[3],@B[2],@t[0],@t[3],0);	# B5A7+B4A8
	vmslg	(@t[4],@B[4],@A[2],@t[4],0);	# B9A4+B8A5
	 vaq	(@t[8],@t[8],@t[7]);		# free t[7]
	vmslg	(@t[5],@B[3],@t[0],@t[5],0);	# B7A7+B6A8
	vmslg	(@t[11],@B[4],@A[3],@t[11],0);	# B9A6+B8A7
	vmslg	(@t[6],@B[4],@t[0],$vzero,0);	# B9A7+B8A8, free t[0]
	 vmrlg	(@t[0],@A[4],$vzero);		# A900 XXX
	 vstef	(@t[8],"48+3($r)",3);
	 vsteh	(@t[8],"48+1($r)",5);
	 vsteb	(@t[8],"48($r)",9);
	 vsldb	(@t[8],$vzero,@t[8],9);
	vmslg	(@t[7],@B[4],@A[4],$vzero,0);	# B9A8+B8A9

	vmslg	(@t[1],@B[0],@t[0],@t[1],0);	# B1A9+B000
	vmslg	(@t[3],@B[1],@t[0],@t[3],0);	# B3A9+B200
	 vaq	(@t[9],@t[9],@t[8]);		# free t[8]
	vmslg	(@t[5],@B[2],@t[0],@t[5],0);	# B5A9+B400
	vmslg	(@t[6],@B[3],@t[0],@t[6],0);	# B7A9+B600
	vmslg	(@t[8],@B[4],@t[0],$vzero,0);	# B9A9+B800
	 vstef	(@t[9],"56+4($r)",3);
	 vsteh	(@t[9],"56+2($r)",5);
	 vsteb	(@t[9],"56+1($r)",9);
	 vsldb	(@t[9],$vzero,@t[9],9);

	vaq	(@t[10],@t[10],@t[9]);

	vsteb	(@t[10],"56($r)",15);
	vsteb	(@t[10],"64+7($r)",14);
	vsteh	(@t[10],"64+5($r)",6);
	vsteh	(@t[10],"64+3($r)",5);
	vsteb	(@t[10],"64+2($r)",9);
	vsldb	(@t[10],$vzero,@t[10],9);

	vaq	(@t[1],@t[1],@t[10]);

	vsteh	(@t[1],"64($r)",7);
	vsteh	(@t[1],"72+6($r)",6);
	vsteh	(@t[1],"72+4($r)",5);
	vsteb	(@t[1],"72+3($r)",9);
	vsldb	(@t[1],$vzero,@t[1],9);

	vaq	(@t[2],@t[2],@t[1]);

	vsteh	(@t[2],"72+1($r)",7);
	vsteb	(@t[2],"72($r)",13);
	vsteb	(@t[2],"80+7($r)",12);
	vsteh	(@t[2],"80+5($r)",5);
	vsteb	(@t[2],"80+4($r)",9);
	vsldb	(@t[2],$vzero,@t[2],9);

	vaq	(@t[3],@t[3],@t[2]);

	vstef	(@t[3],"80($r)",3);
	vsteh	(@t[3],"88+6($r)",5);
	vsteb	(@t[3],"88+5($r)",9);
	vsldb	(@t[3],$vzero,@t[3],9);

	vaq	(@t[4],@t[4],@t[3]);

	vstef	(@t[4],"88+1($r)",3);
	vsteb	(@t[4],"88($r)",11);
	vsteb	(@t[4],"96+7($r)",10);
	vsteb	(@t[4],"96+6($r)",9);
	vsldb	(@t[4],$vzero,@t[4],9);

	vaq	(@t[5],@t[5],@t[4]);

	vstef	(@t[5],"96+2($r)",3);
	vsteh	(@t[5],"96($r)",5);
	vsteb	(@t[5],"104+7($r)",9);
	vsldb	(@t[5],$vzero,@t[5],9);

	vaq	(@t[11],@t[11],@t[5]);

	vstef	(@t[11],"104+3($r)",3);
	vsteh	(@t[11],"104+1($r)",5);
	vsteb	(@t[11],"104($r)",9);
	vsldb	(@t[11],$vzero,@t[11],9);

	vaq	(@t[6],@t[6],@t[11]);

	vstef	(@t[6],"112+4($r)",3);
	vsteh	(@t[6],"112+2($r)",5);
	vsteb	(@t[6],"112+1($r)",9);
	vsldb	(@t[6],$vzero,@t[6],9);

	vaq	(@t[7],@t[7],@t[6]);

	vsteb	(@t[7],"112($r)",15);
	vsteb	(@t[7],"120+7($r)",14);
	vsteh	(@t[7],"120+5($r)",6);
	vsteh	(@t[7],"120+3($r)",5);
	vsteb	(@t[7],"120+2($r)",9);
	vsldb	(@t[7],$vzero,@t[7],9);

	vaq	(@t[8],@t[8],@t[7]);

	vsteh	(@t[8],"120($r)",7);

VERBATIM("#if !defined(__s390x__) && !defined(__s390x)\n");
	ld	("%f4","16*4+2*8($sp)");
	ld	("%f6","16*4+3*8($sp)");
VERBATIM("#endif\n");

	lghi	("%r2",0);
	br	("%r14");
ALIGN	(8);
LABEL	(".Lmul512_novx");
	lghi	("%r2",1);
	br	("%r14");
SIZE	("ica_mp_mul512",".-ica_mp_mul512");
}

# int ica_mp_sqr512(uint64_t *r, const uint64_t *a);
{
my @A=map("%v$_",(0..4));
my @B=map("%v$_",(5..7,16,17));
my @t=map("%v$_",(18..30));
my $vzero="%v31";

my ($r,$a,$c1,$c2,$c3)=map("%r$_",(2..3,1,5,8));

GLOBL	("ica_mp_sqr512");
TYPE	("ica_mp_sqr512","\@function");
ALIGN	(16);
LABEL	("ica_mp_sqr512");
	larl	("%r1","facility_bits");
	lg	("%r0","16(%r1)");
	tmhh	("%r0",0x300);			# check for vector enhancement
	jz	(".Lsqr512_novx");		# and packed decimal facilities

VERBATIM("#if !defined(__s390x__) && !defined(__s390x)\n");
	std	("%f4","16*4+2*8($sp)");
	std	("%f6","16*4+3*8($sp)");
VERBATIM("#endif\n");

	larl	("%r1",".Lconst");

	vzero	($vzero);
	vlm	(@t[0],@t[3],"0($a)");
	vlm	(@t[4],@t[8],"0(%r1)");
	vgbm	(@t[9],0x7f7f);

	# load b (base 2^64 -> base 2^56)
	vperm	(@B[0],@t[0],$vzero,@t[4]);	# B1B0
	vperm	(@B[1],@t[1],@t[0],@t[5]);	# B3B2
	vperm	(@B[2],@t[2],@t[1],@t[6]);	# B5B4
	vperm	(@B[3],@t[3],@t[2],@t[7]);	# B7B6
	vperm	(@B[4],$vzero,@t[3],@t[8]);	# B9B8
	vn	(@B[1],@B[1],@t[9]);
	vn	(@B[2],@B[2],@t[9]);
	vn	(@B[3],@B[3],@t[9]);

	vpdi	(@A[0],@B[0],@B[0],4);
	vpdi	(@A[1],@B[1],@B[1],4);
	vpdi	(@A[2],@B[2],@B[2],4);
	vpdi	(@A[3],@B[3],@B[3],4);
	vpdi	(@A[4],@B[4],@B[4],4);

	vmrhg	(@t[0],$vzero,@A[0]);		# 00A0 XXX

	vn	(@A[1],@A[1],@t[9]);
	vn	(@A[2],@A[2],@t[9]);
	vn	(@A[3],@A[3],@t[9]);

	# r = a * b (base 2^56)
	vmslg	(@t[1],@B[0],@t[0],$vzero,0);	# B100+B0A0
	vmslg	(@t[2],@B[0],@A[0],$vzero,0);	# B1A0+B0A1
	vmslg	(@t[3],@B[1],@t[0],$vzero,0);	# B300+B2A0
	vmslg	(@t[4],@B[0],@A[1],$vzero,0);	# B1A2+B0A3
	vmslg	(@t[5],@B[2],@t[0],$vzero,0);	# B500+B4A0
	vmslg	(@t[6],@B[0],@A[2],$vzero,0);	# B1A4+B0A5
	vmslg	(@t[7],@B[3],@t[0],$vzero,0);	# B700+B6A0
	vmslg	(@t[8],@B[0],@A[3],$vzero,0);	# B1A6+B0A7
	vmslg	(@t[9],@B[4],@t[0],$vzero,0);	# B900+B8A0, free t[0]
	 vsldb	(@t[0],@A[0],@A[1],8);		# A1A2 XXX
	vmslg	(@t[10],@B[0],@A[4],$vzero,0);	# B1A8+B0A9

	 vstrl	(@t[1],"1($r)",6);
	 vsldb	(@t[1],$vzero,@t[1],9);
	vmslg	(@t[3],@B[0],@t[0],@t[3],0);	# B1A1+B0A2
	vmslg	(@t[4],@B[1],@A[0],@t[4],0);	# B3A0+B2A1
	vmslg	(@t[5],@B[1],@t[0],@t[5],0);	# B3A1+B2A2
	 vaq	(@t[2],@t[2],@t[1]);		# free t[1]
	vmslg	(@t[6],@B[1],@A[1],@t[6],0);	# B3A2+B2A3
	vmslg	(@t[7],@B[2],@t[0],@t[7],0);	# B5A1+B4A2
	vmslg	(@t[8],@B[1],@A[2],@t[8],0);	# B3A4+B2A5
	 vsteb	(@t[2],"0($r)",15);
	 vsteb	(@t[2],"8+7($r)",14);
	 vsteh	(@t[2],"8+5($r)",6);
	 vsteh	(@t[2],"8+3($r)",5);
	 vsteb	(@t[2],"8+2($r)",9);
	 vsldb	(@t[2],$vzero,@t[2],9);
	vmslg	(@t[9],@B[3],@t[0],@t[9],0);	# B7A1+B6A2
	vmslg	(@t[10],@B[1],@A[3],@t[10],0);	# B3A6+B2A7
	vmslg	(@t[1],@B[4],@t[0],$vzero,0);	# B9A1+B8A2, free t[0]
	 vaq	(@t[3],@t[3],@t[2]);		# free t[2]
	 vsldb	(@t[0],@A[1],@A[2],8);		# A3A4 XXX
	vmslg	(@t[2],@B[1],@A[4],$vzero,0);	# B3A8+B2A9

	vmslg	(@t[5],@B[0],@t[0],@t[5],0);	# B1A3+B0A4
	 vsteh	(@t[3],"8($r)",7);
	 vsteh	(@t[3],"16+6($r)",6);
	 vsteh	(@t[3],"16+4($r)",5);
	 vsteb	(@t[3],"16+3($r)",9);
	 vsldb	(@t[3],$vzero,@t[3],9);
	vmslg	(@t[6],@B[2],@A[0],@t[6],0);	# B5A0+B4A1
	vmslg	(@t[7],@B[1],@t[0],@t[7],0);	# B3A3+B2A4
	vmslg	(@t[8],@B[2],@A[1],@t[8],0);	# B5A2+B4A3
	 vaq	(@t[4],@t[4],@t[3]);		# free t[3]
	vmslg	(@t[9],@B[2],@t[0],@t[9],0);	# B5A3+B4A4
	vmslg	(@t[10],@B[2],@A[2],@t[10],0);	# B5A4+B4A5
	vmslg	(@t[1],@B[3],@t[0],@t[1],0);	# B7A3+B6A4
	 vsteh	(@t[4],"16+1($r)",7);
	 vsteb	(@t[4],"16($r)",13);
	 vsteb	(@t[4],"24+7($r)",12);
	 vsteh	(@t[4],"24+5($r)",5);
	 vsteb	(@t[4],"24+4($r)",9);
	 vsldb	(@t[4],$vzero,@t[4],9);
	vmslg	(@t[2],@B[2],@A[3],@t[2],0);	# B5A6+B4A7
	vmslg	(@t[3],@B[4],@t[0],$vzero,0);	# B9A3+B8A4, free t[0]
	 vsldb	(@t[0],@A[2],@A[3],8);		# A5A6 XXX
	 vaq	(@t[5],@t[5],@t[4]);		# fee t[4]
	vmslg	(@t[4],@B[2],@A[4],$vzero,0);	# B5A8+B4A9

	vmslg	(@t[7],@B[0],@t[0],@t[7],0);	# B1A5+B0A6
	vmslg	(@t[8],@B[3],@A[0],@t[8],0);	# B7A0+B6A1
	 vstef	(@t[5],"24($r)",3);
	 vsteh	(@t[5],"32+6($r)",5);
	 vsteb	(@t[5],"32+5($r)",9);
	 vsldb	(@t[5],$vzero,@t[5],9);
	vmslg	(@t[9],@B[1],@t[0],@t[9],0);	# B3A5+B2A6
	vmslg	(@t[10],@B[3],@A[1],@t[10],0);	# B7A2+B6A3
	vmslg	(@t[1],@B[2],@t[0],@t[1],0);	# B5A5+B4A6
	 vaq	(@t[6],@t[6],@t[5]);		# free t[5]
	vmslg	(@t[2],@B[3],@A[2],@t[2],0);	# B7A4+B6A5
	vmslg	(@t[3],@B[3],@t[0],@t[3],0);	# B7A5+B6A6
	vmslg	(@t[4],@B[3],@A[3],@t[4],0);	# B7A6+B6A7
	 vstef	(@t[6],"32+1($r)",3);
	 vsteb	(@t[6],"32($r)",11);
	 vsteb	(@t[6],"40+7($r)",10);
	 vsteb	(@t[6],"40+6($r)",9);
	 vsldb	(@t[6],$vzero,@t[6],9);
	vmslg	(@t[5],@B[4],@t[0],$vzero,0);	# B9A5+B8A6, free t[0]
	 vsldb	(@t[0],@A[3],@A[4],8);		# A7A8 XXX
	vmslg	(@t[11],@B[3],@A[4],$vzero,0);	# B7A8+B6A9

	 vaq	(@t[7],@t[7],@t[6]);		# free t[6]
	vmslg	(@t[9],@B[0],@t[0],@t[9],0);	# B1A7+B0A8
	vmslg	(@t[10],@B[4],@A[0],@t[10],0);	# B9A0+B8A1
	vmslg	(@t[1],@B[1],@t[0],@t[1],0);	# B3A7+B2A8
	 vstef	(@t[7],"40+2($r)",3);
	 vsteh	(@t[7],"40($r)",5);
	 vsteb	(@t[7],"48+7($r)",9);
	 vsldb	(@t[7],$vzero,@t[7],9);
	vmslg	(@t[2],@B[4],@A[1],@t[2],0);	# B9A2+B8A3
	vmslg	(@t[3],@B[2],@t[0],@t[3],0);	# B5A7+B4A8
	vmslg	(@t[4],@B[4],@A[2],@t[4],0);	# B9A4+B8A5
	 vaq	(@t[8],@t[8],@t[7]);		# free t[7]
	vmslg	(@t[5],@B[3],@t[0],@t[5],0);	# B7A7+B6A8
	vmslg	(@t[11],@B[4],@A[3],@t[11],0);	# B9A6+B8A7
	vmslg	(@t[6],@B[4],@t[0],$vzero,0);	# B9A7+B8A8, free t[0]
	 vmrlg	(@t[0],@A[4],$vzero);		# A900 XXX
	 vstef	(@t[8],"48+3($r)",3);
	 vsteh	(@t[8],"48+1($r)",5);
	 vsteb	(@t[8],"48($r)",9);
	 vsldb	(@t[8],$vzero,@t[8],9);
	vmslg	(@t[7],@B[4],@A[4],$vzero,0);	# B9A8+B8A9

	vmslg	(@t[1],@B[0],@t[0],@t[1],0);	# B1A9+B000
	vmslg	(@t[3],@B[1],@t[0],@t[3],0);	# B3A9+B200
	 vaq	(@t[9],@t[9],@t[8]);		# free t[8]
	vmslg	(@t[5],@B[2],@t[0],@t[5],0);	# B5A9+B400
	vmslg	(@t[6],@B[3],@t[0],@t[6],0);	# B7A9+B600
	vmslg	(@t[8],@B[4],@t[0],$vzero,0);	# B9A9+B800
	 vstef	(@t[9],"56+4($r)",3);
	 vsteh	(@t[9],"56+2($r)",5);
	 vsteb	(@t[9],"56+1($r)",9);
	 vsldb	(@t[9],$vzero,@t[9],9);

	vaq	(@t[10],@t[10],@t[9]);

	vsteb	(@t[10],"56($r)",15);
	vsteb	(@t[10],"64+7($r)",14);
	vsteh	(@t[10],"64+5($r)",6);
	vsteh	(@t[10],"64+3($r)",5);
	vsteb	(@t[10],"64+2($r)",9);
	vsldb	(@t[10],$vzero,@t[10],9);

	vaq	(@t[1],@t[1],@t[10]);

	vsteh	(@t[1],"64($r)",7);
	vsteh	(@t[1],"72+6($r)",6);
	vsteh	(@t[1],"72+4($r)",5);
	vsteb	(@t[1],"72+3($r)",9);
	vsldb	(@t[1],$vzero,@t[1],9);

	vaq	(@t[2],@t[2],@t[1]);

	vsteh	(@t[2],"72+1($r)",7);
	vsteb	(@t[2],"72($r)",13);
	vsteb	(@t[2],"80+7($r)",12);
	vsteh	(@t[2],"80+5($r)",5);
	vsteb	(@t[2],"80+4($r)",9);
	vsldb	(@t[2],$vzero,@t[2],9);

	vaq	(@t[3],@t[3],@t[2]);

	vstef	(@t[3],"80($r)",3);
	vsteh	(@t[3],"88+6($r)",5);
	vsteb	(@t[3],"88+5($r)",9);
	vsldb	(@t[3],$vzero,@t[3],9);

	vaq	(@t[4],@t[4],@t[3]);

	vstef	(@t[4],"88+1($r)",3);
	vsteb	(@t[4],"88($r)",11);
	vsteb	(@t[4],"96+7($r)",10);
	vsteb	(@t[4],"96+6($r)",9);
	vsldb	(@t[4],$vzero,@t[4],9);

	vaq	(@t[5],@t[5],@t[4]);

	vstef	(@t[5],"96+2($r)",3);
	vsteh	(@t[5],"96($r)",5);
	vsteb	(@t[5],"104+7($r)",9);
	vsldb	(@t[5],$vzero,@t[5],9);

	vaq	(@t[11],@t[11],@t[5]);

	vstef	(@t[11],"104+3($r)",3);
	vsteh	(@t[11],"104+1($r)",5);
	vsteb	(@t[11],"104($r)",9);
	vsldb	(@t[11],$vzero,@t[11],9);

	vaq	(@t[6],@t[6],@t[11]);

	vstef	(@t[6],"112+4($r)",3);
	vsteh	(@t[6],"112+2($r)",5);
	vsteb	(@t[6],"112+1($r)",9);
	vsldb	(@t[6],$vzero,@t[6],9);

	vaq	(@t[7],@t[7],@t[6]);

	vsteb	(@t[7],"112($r)",15);
	vsteb	(@t[7],"120+7($r)",14);
	vsteh	(@t[7],"120+5($r)",6);
	vsteh	(@t[7],"120+3($r)",5);
	vsteb	(@t[7],"120+2($r)",9);
	vsldb	(@t[7],$vzero,@t[7],9);

	vaq	(@t[8],@t[8],@t[7]);

	vsteh	(@t[8],"120($r)",7);

VERBATIM("#if !defined(__s390x__) && !defined(__s390x)\n");
	ld	("%f4","16*4+2*8($sp)");
	ld	("%f6","16*4+3*8($sp)");
VERBATIM("#endif\n");

	lghi	("%r2",0);
	br	("%r14");
ALIGN	(8);
LABEL	(".Lsqr512_novx");
	lghi	("%r2",1);
	br	("%r14");
SIZE	("ica_mp_sqr512",".-ica_mp_sqr512");
}

ALIGN	(128);
LABEL	(".Lconst");
LONG	(0x100a0b0c,0x0d0e0f00,0x10010203,0x04050607);
LONG	(0x100c0d0e,0x0f000102,0x10030405,0x06071819);
LONG	(0x100e0f00,0x01020304,0x10050607,0x18191a1b);
LONG	(0x10000102,0x03040506,0x10071819,0x1a1b1c1d);
LONG	(0x00000000,0x00000018,0x00191a1b,0x1c1d1e1f);

PERLASM_END();
