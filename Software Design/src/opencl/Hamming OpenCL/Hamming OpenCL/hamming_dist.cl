/*
The MIT License

Copyright (c) 2017 Florian Porrmann

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

#include "hamming.h"


uint accumulate_uint16(uint16 val)
{
	val.s01234567 = val.s01234567 + val.s89abcdef;
	val.s0123 = val.s0123 + val.s4567;
	val.s01 = val.s01 + val.s23;
	return val.s0 + val.s1;
}

__kernel //__attribute__ ((reqd_work_group_size(256, 1, 1)))
void hamming_dist(__global ulong* pC, __global uint16* pA, __global uint16* pB, uint seqBLength, uint seqBOffset, uint threshold, __global uint* pResCnt)
{
	local uint16 staticData[SEQ_A_SIZE];
	local uint16 dynamicData[SEQ_A_SIZE];
	local ulong result;
	local uint resCnt[1];

	resCnt[0] = *pResCnt;

	if(resCnt[0] >= MAX_OUTPUT_DATA_SIZE)
	{
		return; // Exit here incase the output buffer is full
	}

	async_work_group_copy(staticData, pA, SEQ_A_SIZE, 0);
	async_work_group_copy(dynamicData, pB, seqBLength, 0);

// Loop over the static data of sequence A
	for (ulong i = 0; i < SEQ_A_SIZE; i++)
	{
		// Loop over the dynamic data of sequence B
		for (ulong j = 0; j < seqBLength; j++)
		{
			result = accumulate_uint16(popcount(staticData[i] ^ dynamicData[j])); // Hamming distance
			if (result < threshold)
			{
				result |= (j + seqBOffset) << 10; // Index B
				result |= i << 37; // Index A

				pC[resCnt[0]] = result;
				resCnt[0]++;

				if(resCnt[0] >= MAX_OUTPUT_DATA_SIZE)
				{
					async_work_group_copy(pResCnt, &resCnt[0], 1, 0);
					return; // Exit here incase the output buffer is full
				}
			}
		}
	}

	async_work_group_copy(pResCnt, &resCnt[0], 1, 0);
}
