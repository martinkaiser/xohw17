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

#include <iostream>
#include <fstream>
#include <vector>
#include <regex>
#include <stdint.h>

struct Result
{
		uint64_t val;

		uint16_t dist;
		uint32_t idxB;
		uint32_t idxA;

		CalcValues()
		{
			dist = (uint16_t)val & 0x3FF;
			idxB = (uint32_t)(val >> 10) & 0x7FFFFFF;
			idxA = (uint32_t)(val >> 37) & 0x7FFFFFF;
      
      
      
		}

};

using Sequence  = uint32_t;
using Sequences = std::vector<Sequence>;
using Results   = std::vector<Result>;


Sequences getTagValues(std::vector<std::string> fileContent, std::string tag, bool reverse = false)
{
	Sequences ret;
	// Regex to match hex numbers in the form 0xHHHHHHHH
	// adjust {8} to increase or decrease the length (8 - matches 8 characters)
	std::regex rx("0x[\\da-fA-F]{8}");
	std::smatch match;

	// Iterate over whole file
	for(std::vector<std::string>::iterator it = fileContent.begin() ; it != fileContent.end(); ++it)
	{
		// Check if the current line contains the searched tag
		if((*it).find(tag) != std::string::npos)
		{
			if(std::regex_search(*it, match, rx))
			{
				// By design there will only be one hex value per line
				Sequence seq = std::stoul(match[0], nullptr, 16);
				if(!reverse)
					ret.push_back(seq);
				else
					ret.insert(ret.begin(), seq);
			}
		}
	}

	return ret;
}

Results mergeSequencesToResults(Sequences vec)
{
	Result res;
	Results ret;
	bool lower = true;

	for(Sequences::iterator it = vec.begin(); it != vec.end(); it++)
	{
		if(lower)
		{
			res.val = *it;
			lower = false;
		}
		else
		{
			res.val |= (uint64_t)*it << 32;
			res.CalcValues();
			lower = true;
			ret.push_back(res);
		}
	}

	return ret;
}

uint32_t popCnt32(uint32_t n)
{
	n -= ((n >> 1) & 0x55555555);
	n = (n & 0x33333333) + ((n >> 2) & 0x33333333);
	return (((n + (n >> 4)) & 0xF0F0F0F) * 0x1010101) >> 24;
}

int main(int argc, char *argv[])
{
	std::vector<std::string> fileContent;
	std::string s;

	if(argc < 2)
	{
		// For this kind of printing printf is just better
		printf("Usage: %s TRANSCRIPT_FILE\n", argv[0]);
		return -1;
	}
	
	std::ifstream infile(argv[1]);

	if(!infile.is_open())
	{
		std::cout << "Error while opening the transcript file." << std::endl;
		return -1;
	}

	// Read file content line by line into vector
	while (std::getline(infile, s))
		fileContent.push_back(s);


//	Result t;
//	t.val = 0x2000000404;
//	t.CalcValues();

//	std::cout << "t: " << t.val << std::endl
//	          << "dist: " << t.dist << std::endl
//	          << "idxA: " << t.idxA << std::endl
//	          << "idxB: " << t.idxB << std::endl;

//	return 0;

	Sequences sa = getTagValues(fileContent, "Wrote SA:", true);
	Sequences sb = getTagValues(fileContent, "Wrote SB:");
	Results res = mergeSequencesToResults(getTagValues(fileContent, "Read result:"));

	int missCnt = 0;
	int matchCnt = 0;

	for(Result r : res)
	{
		if(r.idxA >= sa.size() || r.idxB >= sb.size())
		{
			std::cout << std::endl << "Index A: " << std::hex << r.idxA << " or Index B: " << std::hex << r.idxB
			          << " exceed the sequence size, skipping current result." << std::endl << std::endl;
			continue;
		}

//		std::cout << "Full Value: " << std::hex << r.val << std::endl
//		          << "Index A: " << std::hex << r.idxA << std::endl
//		          << "Index B: " << std::hex << r.idxB << std::endl
//		          << "Dist   : " << std::hex << r.dist << std::endl
//		          << "Value A: " << std::hex << sa.at(r.idxA) << std::endl
//		          << "Value B: " << std::hex << sb.at(r.idxB) << std::endl;

		uint32_t dist = popCnt32(sa.at(r.idxA) ^ sb.at(r.idxB));

		if(dist != r.dist)
		{
			std::cout << std::endl << "Mismatch:" << std::endl
			          << "Index A: " << std::hex << r.idxA << std::endl
			          << "Index B: " << std::hex << r.idxB << std::endl
			          << "Value A: " << std::hex << sa.at(r.idxA) << std::endl
			          << "Value B: " << std::hex << sb.at(r.idxB) << std::endl
			          << "VHDL: " << std::hex << r.dist << std::endl
			          << "C++:  " << std::hex << dist << std::endl;

			missCnt++;
		}
		else
    {
      std::cout << std::endl << "Match :-D" << std::endl
                << "Index A: " << std::hex << r.idxA << std::endl
			          << "Index B: " << std::hex << r.idxB << std::endl
			          << "Value A: " << std::hex << sa.at(r.idxA) << std::endl
			          << "Value B: " << std::hex << sb.at(r.idxB) << std::endl
			          << "VHDL: " << std::hex << r.dist << std::endl
			          << "C++:  " << std::hex << dist << std::endl;
			matchCnt++;
    }
	}

	std::cout << std::endl << "Misses: " << std::dec << missCnt << std::endl << "Matches: " << matchCnt << std::endl;

	return 0;
}
