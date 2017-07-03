/**********
Copyright (c) 2017, Xilinx, Inc.
All rights reserved.
Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:
1. Redistributions of source code must retain the above copyright notice,
this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors
may be used to endorse or promote products derived from this software
without specific prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**********/

#include <string.h>
#include <iostream>
#include <vector>
#include <random>
#include <algorithm>
#include <array>
#include <limits>
#include <fstream>
#include <iomanip>
#include <string>

#include "hamming.h"
#include "xcl.h"
#include "oclErrorCodes.h"
#include "Timer.h"

#define PERFORMACE

typedef uint8_t byte;
typedef std::vector<byte> bytes;

struct hash
{
		uint8_t bytes[64];

		hash operator^(const hash& h1)
		{
			hash res;
			for (int i = 0; i < 64; i++)
				res.bytes[i] = this->bytes[i] ^ h1.bytes[i];

			return res;
		}

		friend std::ostream& operator<<(std::ostream& stream, const hash &h)
		{
			for (int i = 0; i < 64; i++)
				stream << std::hex << std::setfill('0') << std::setw(2) << std::nouppercase << (int) h.bytes[i];

			return stream;
		}
};

struct Result
{
		uint64_t val;

		uint16_t dist;
		uint32_t idxB;
		uint32_t idxA;

		Result(uint64_t v)
		{
			val = v;
			CalcValues();
		}

		void CalcValues()
		{
			dist = (uint16_t) val & 0x3FF;
			idxB = (uint32_t) (val >> 10) & 0x7FFFFFF;
			idxA = (uint32_t) (val >> 37) & 0x7FFFFFF;
		}

};

int fromHex(char _i)
{
	if (_i >= '0' && _i <= '9')
		return _i - '0';
	if (_i >= 'a' && _i <= 'f')
		return _i - 'a' + 10;
	if (_i >= 'A' && _i <= 'F')
		return _i - 'A' + 10;

	return -1;
}

bytes hexStringToBytes(std::string const& _s)
{
	unsigned s = (_s[0] == '0' && _s[1] == 'x') ? 2 : 0;
	std::vector<uint8_t> ret;
	ret.reserve((_s.size() - s + 1) / 2);

	if (_s.size() % 2)
	{
		try
		{
			ret.push_back(fromHex(_s[s++]));
		}
		catch (...)
		{
			ret.push_back(0);
		}
	}

	for (unsigned i = s; i < _s.size(); i += 2)
	{
		try
		{
			ret.push_back((byte) (fromHex(_s[i]) * 16 + fromHex(_s[i + 1])));
		}
		catch (...)
		{
			ret.push_back(0);
		}
	}

	return ret;
}

hash stringToHash(std::string const& _s)
{
	hash ret;
	bytes b = hexStringToBytes(_s);
	memcpy(&ret.bytes, b.data(), b.size());
	return ret;
}

std::string hps(double val)
{
	std::string str = "";
	int cnt = 0;

	while (val / 1000.0 > 1.0)
	{
		val /= 1000.0;
		cnt++;
	}

	str.append(std::_Floating_to_string("%0.3f", val));

	switch (cnt)
	{
		// hash per second
	case 0:
		str.append(" h/s");
		break;

		// kilo hash per second
	case 1:
		str.append(" Kh/s");
		break;

		// mega hash per second
	case 2:
		str.append(" Mh/s");
		break;

		// giga hash per second
	case 3:
		str.append(" Gh/s");
		break;

		// tera hash per second
	case 4:
		str.append(" Th/s");
		break;
	}

	return str;
}

// Wrap any OpenCL API calls that return error code(cl_int) with the below macro
// to quickly check for an error
#define OCL_CHECK(call)                                                              \
	do                                                                               \
	{                                                                                \
		cl_int err = call;                                                           \
		if (err != CL_SUCCESS)                                                       \
		{                                                                            \
			printf("Error calling " #call ", error: %s\n", oclErrorCode(err));       \
			exit(EXIT_FAILURE);                                                      \
		}                                                                            \
	} while (0);

uint32_t popCnt32(uint32_t n)
{
	n -= ((n >> 1) & 0x55555555);
	n = (n & 0x33333333) + ((n >> 2) & 0x33333333);
	return (((n + (n >> 4)) & 0xF0F0F0F) * 0x1010101) >> 24;
}

uint8_t popCnt8(uint8_t uc)
{
	uint8_t n;
	n = ((uc >> 1) & 0x55) + (uc & 0x55);
	n = ((n >> 2) & 0x33) + (n & 0x33);
	return (n >> 4) + (n & 0x0f);
}

uint32_t popCnt512(hash n)
{
	uint32_t res = 0;

	for (int i = 0; i < 64; i++)
		res += popCnt8(n.bytes[i]);

	return res;
}

int gen_random()
{
	static std::default_random_engine e;
	static std::uniform_int_distribution<int> dist(0, 100);

	return dist(e);
}

int main(int argc, char* argv[])
{
	Timer fullTime;
	fullTime.start();
	cl_int err;

	if (argc < 4)
	{
		std::cout << "Usage: " << argv[0] << " <kernel> <global-size> <local-size>" << std::endl;
		return -1;
	}

	const char *pXclbinFilename = argv[1];

	xcl_world world;
	cl_kernel krnl;

	if (strstr(argv[1], ".xclbin") != NULL)
	{
//		world = xcl_world_single(CL_DEVICE_TYPE_ACCELERATOR, tarVendor, pTarDevName);
		krnl = xcl_import_binary(world, pXclbinFilename, "hamming_dist");
	}
	else
	{
		world = xcl_world_single(CL_DEVICE_TYPE_CPU, NULL, NULL);
		krnl = xcl_import_source(world, pXclbinFilename, "hamming_dist");
	}

	// --------- LOAD INPUT DATA ---------
	Timer execTimer;
	execTimer.start();

	std::vector<hash> staticData;
	std::vector<hash> dynData;

	std::ifstream infile("a.txt");

	if (!infile.is_open())
	{
		std::cout << "Error while opening the input file. Current Directory: " << system("pwd") << std::endl;
		return -1;
	}

	std::string s;
	while (infile >> s)
		staticData.push_back(stringToHash(s));

	infile.close();
	infile.open("b_1m.txt");

	if (!infile.is_open())
	{
		std::cout << "Error while opening the input file. Current Directory: " << system("pwd") << std::endl;
		return -1;
	}

	while (infile >> s)
		dynData.push_back(stringToHash(s));

	printf("---Static Data(%lu)---\nFirst: ", staticData.size());

	for (int j = 0; j < 64; j++)
		printf("%02x", staticData.front().bytes[j]);

	printf("\nLast:  ");

	for (int j = 0; j < 64; j++)
		printf("%02x", staticData.back().bytes[j]);

	printf("\n");

	printf("---Dynamic Data(%lu)---\nFirst: ", dynData.size());

	for (int j = 0; j < 64; j++)
		printf("%02x", dynData.front().bytes[j]);

	printf("\nLast:  ");

	for (int j = 0; j < 64; j++)
		printf("%02x", dynData.back().bytes[j]);

	printf("\n");

	execTimer.stop();
	printf("Input data load time: %0.3f ms\n", execTimer.getElapsedTimeInMilliSec());

	// --------- LOAD INPUT DATA ---------

	// We will break down our problem into multiple iterations. Each iteration
	// will perform computation on a subset of the entire data-set.
	size_t elements_per_iteration = SEQ_A_SIZE;
	size_t num_iterations = (dynData.size() + elements_per_iteration - 1) / elements_per_iteration;

	if (num_iterations < 1)
		num_iterations = 1;

	clReleaseCommandQueue(world.command_queue);
	world.command_queue = clCreateCommandQueue(world.context, world.device_id, CL_QUEUE_OUT_OF_ORDER_EXEC_MODE_ENABLE | CL_QUEUE_PROFILING_ENABLE, &err);

	std::vector<uint64_t> deviceResult(MAX_OUTPUT_DATA_SIZE);

	// This pair of events will be used to track when a kernel is finished with
	// the input buffers. Once the kernel is finished processing the data, a new
	// set of elements will be written into the buffer.
	std::array<cl_event, 2> kernel_events;
	std::array<cl_event, 2> read_events;

	cl_mem staticDataBuffer = clCreateBuffer(world.context, CL_MEM_READ_ONLY | CL_MEM_USE_HOST_PTR, SEQ_A_BYTE_SIZE, staticData.data(), NULL);

	cl_mem dynamicDataBuffer[2];

	uint32_t resCnt = 0;

	cl_mem resCntBuffer = clCreateBuffer(world.context, CL_MEM_READ_WRITE, sizeof(uint32_t), NULL, NULL);
	clEnqueueWriteBuffer(world.command_queue, resCntBuffer, CL_FALSE, 0, sizeof(uint32_t), &resCnt, 0, NULL, NULL);

	cl_event staticEvent;
	OCL_CHECK(clEnqueueMigrateMemObjects(world.command_queue, 1, &staticDataBuffer, 0 /* flags, 0 means from host */, 0, NULL, &staticEvent));

	xcl_set_kernel_arg(krnl, 6, sizeof(cl_mem), &resCntBuffer);
	xcl_set_kernel_arg(krnl, 1, sizeof(cl_mem), &staticDataBuffer);
	clWaitForEvents(1, &staticEvent);

	cl_ulong write_time = 0;
	cl_ulong time_start;
	cl_ulong time_end;

	size_t global = atoi(argv[2]);
	size_t local = atoi(argv[3]);

	cl_ulong kernelExecTime = 0;

	uint32_t threshold = 200;

	xcl_set_kernel_arg(krnl, 5, sizeof(uint32_t), &threshold);

	cl_mem outputBuffer = clCreateBuffer(world.context, CL_MEM_WRITE_ONLY | CL_MEM_USE_HOST_PTR, MAX_OUTPUT_DATA_SIZE * sizeof(uint64_t), &deviceResult[0], NULL);
	xcl_set_kernel_arg(krnl, 0, sizeof(cl_mem), &outputBuffer);

	std::cout << "Iterations: " << num_iterations << std::endl;

	execTimer.start();

	for (size_t iteration_idx = 0; iteration_idx < num_iterations; iteration_idx++)
	{
		int flag = iteration_idx % 2;
		uint32_t seqBOffset = elements_per_iteration * iteration_idx;

		uint32_t seqBPartLength = (dynData.size() - seqBOffset < (uint32_t) SEQ_A_SIZE) ? dynData.size() - seqBOffset : SEQ_A_SIZE;

		if (iteration_idx >= 2)
		{
			clWaitForEvents(1, &read_events[flag]);

			if (kernel_events[flag])
			{
				clWaitForEvents(1, &kernel_events[flag]);
				clGetEventProfilingInfo(kernel_events[flag], CL_PROFILING_COMMAND_START, sizeof(cl_ulong), &time_start, NULL);
				clGetEventProfilingInfo(kernel_events[flag], CL_PROFILING_COMMAND_END, sizeof(cl_ulong), &time_end, NULL);
				if (time_end >= time_start)
					kernelExecTime += time_end - time_start;
			}

			OCL_CHECK(clReleaseMemObject(dynamicDataBuffer[flag]));
			OCL_CHECK(clReleaseEvent(read_events[flag]));
			OCL_CHECK(clReleaseEvent(kernel_events[flag]));
			dynamicDataBuffer[flag] = nullptr;
			read_events[flag] = nullptr;
			kernel_events[flag] = nullptr;
		}

		if (resCnt >= (uint32_t) MAX_OUTPUT_DATA_SIZE)
		{
			std::cout << "Result overflow, to many possible results to fit into memory, please adjust the threshold." << std::endl;
			break;
		}

		dynamicDataBuffer[flag] = clCreateBuffer(world.context, CL_MEM_READ_ONLY | CL_MEM_USE_HOST_PTR, SEQ_A_BYTE_SIZE, &dynData[seqBOffset], NULL);

		cl_event write_event;

		OCL_CHECK(clEnqueueMigrateMemObjects(world.command_queue, 1, &dynamicDataBuffer[flag], 0 /* flags, 0 means from host */, 0, NULL, &write_event));

		xcl_set_kernel_arg(krnl, 2, sizeof(cl_mem), &dynamicDataBuffer[flag]);
		xcl_set_kernel_arg(krnl, 3, sizeof(uint32_t), &seqBPartLength);
		xcl_set_kernel_arg(krnl, 4, sizeof(uint32_t), &seqBOffset);

		OCL_CHECK(clEnqueueNDRangeKernel(world.command_queue, krnl, 1, nullptr, &global, &local, 1, &write_event, &kernel_events[flag]));

		clEnqueueReadBuffer(world.command_queue, resCntBuffer, CL_FALSE, 0, sizeof(uint32_t), &resCnt, 1, &kernel_events[flag], &read_events[flag]);

		clGetEventProfilingInfo(write_event, CL_PROFILING_COMMAND_START, sizeof(cl_ulong), &time_start, NULL);
		clGetEventProfilingInfo(write_event, CL_PROFILING_COMMAND_END, sizeof(cl_ulong), &time_end, NULL);
		if (time_end >= time_start)
			write_time += time_end - time_start;

		OCL_CHECK(clReleaseEvent(write_event));
	}

	// Wait for all of the OpenCL operations to complete
	printf("Waiting...\n");
	clFlush(world.command_queue);
	clFinish(world.command_queue);
	std::cout << "Final Count: " << resCnt << std::endl;

	if (resCnt > 0)
	{
		if (read_events[0])
			OCL_CHECK(clReleaseEvent(read_events[0]));

		OCL_CHECK(clEnqueueMigrateMemObjects(world.command_queue, 1, &outputBuffer, CL_MIGRATE_MEM_OBJECT_HOST, 0, NULL, &read_events[0]));
		clEnqueueMapBuffer(world.command_queue, outputBuffer, CL_TRUE, CL_MAP_READ, 0, resCnt * sizeof(uint64_t), 1, &read_events[0], NULL, 0);
	}

	execTimer.stop();

	// Releasing mem objects and events - make sure to only release 1
	// element in case length(seq A) == length(seq B)
	for (int i = 0; i < (num_iterations < 2 ? 1 : 2); i++)
	{
		if (read_events[i])
			OCL_CHECK(clReleaseEvent(read_events[i]));

		if (kernel_events[i])
		{
			clGetEventProfilingInfo(kernel_events[i], CL_PROFILING_COMMAND_START, sizeof(cl_ulong), &time_start, NULL);
			clGetEventProfilingInfo(kernel_events[i], CL_PROFILING_COMMAND_END, sizeof(cl_ulong), &time_end, NULL);
			if (time_end >= time_start)
				kernelExecTime += time_end - time_start;
			OCL_CHECK(clReleaseEvent(kernel_events[i]));
		}

		if (dynamicDataBuffer[i])
			OCL_CHECK(clReleaseMemObject(dynamicDataBuffer[i]));
	}

	OCL_CHECK(clReleaseMemObject(outputBuffer));
	OCL_CHECK(clReleaseMemObject(staticDataBuffer));
	OCL_CHECK(clReleaseMemObject(resCntBuffer));

	OCL_CHECK(clReleaseKernel(krnl));
	xcl_release_world(world);


#ifdef PERFORMACE
	printf("Entire OpenCL execution time: %0.3f ms\n", execTimer.getElapsedTimeInMilliSec());

	cl_double kernelExecTimeMS = (cl_double)(kernelExecTime)*(cl_double)(1e-06);

	printf("Execution time for %d elements in milliseconds = %0.3f ms\n", SEQ_A_SIZE * dynData.size(), kernelExecTimeMS);
	printf("Hashes per second: %s\n", hps((SEQ_A_SIZE * dynData.size()) / (kernelExecTimeMS / 1000.0)).c_str());

	printf("Write time in milliseconds = %0.3f ms\n", (cl_double)(write_time)*(cl_double)(1e-06));

#endif

	execTimer.start();

	int missCnt = 0;
	int matchCnt = 0;
	int skipCnt = 0;

	for (uint32_t i = 0; i < resCnt; i++)
	{
		Result r(deviceResult.at(i));

		if (r.idxA >= staticData.size() || r.idxB >= dynData.size())
		{
			skipCnt++;
			continue;
		}

		uint32_t dist = popCnt512(staticData.at(r.idxA) ^ dynData.at(r.idxB));

		if (dist != r.dist)
		{
//			std::cout << std::endl << "Mismatch:" << std::endl
//			          << "Index A: " << std::hex << r.idxA << std::endl
//			          << "Index B: " << std::hex << r.idxB << std::endl
//			          << "Value A: " << std::hex << staticData.at(r.idxA) << std::endl
//			          << "Value B: " << std::hex << dynData.at(r.idxB) << std::endl
//			          << "OpenCL: " << std::hex << r.dist << std::endl
//			          << "C++:    " << std::hex << dist << std::endl;

			missCnt++;
		}
		else
			matchCnt++;
	}

	execTimer.stop();

	std::cout << std::endl << "Skips: " << std::dec << skipCnt << std::endl << "Misses: " << missCnt << std::endl << "Matches: " << matchCnt << std::endl;

	printf("CPU compare time: %0.3f ms\n", execTimer.getElapsedTimeInMilliSec());

	fullTime.stop();

	printf("Entire runtime: %0.3f ms\n", fullTime.getElapsedTimeInMilliSec());

	return EXIT_SUCCESS;
}
