<script type="text/javascript" src="http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=default"></script>
<link rel="stylesheet" href="D:\imp\github\highlight.js\src\styles\darcula.css">
<script src="D:\imp\github\highlight.js\src\highlight.js"></script>
<script src="http://yandex.st/highlightjs/8.0/highlight.min.js"></script>
<script src="http://lib.sinaapp.com/js/jquery/1.9.1/jquery-1.9.1.min.js"></script>
<script>hljs.initHighlightingOnLoad();</script>

##排序算法性能对比
排序算法在数据结构中占有很重要的地位，今天总结一下各种算法的复杂度，以及各种算法的Java实现如下。

算法名称|时间复杂度(最差)|时间复杂度(平均)|时间复杂度(最优)|稳定性|空间复杂度
---|---|---|---|----|---
直接插入排序| $$n^2$$ |$$n^2$$|n|稳定|1
折半插入排序||||
希尔排序|$$n\log_2 n$$|$$n\log_2 n$$|根据步长d选择不同，最优不确定|不稳定|1
冒泡排序|$$n^2$$|$$n^2$$|$$n$$|稳定|1
快速排序|$$n^2$$|$$n\log_2 n$$|$$n\log_2 n$$|不稳定|$$\log_2 n - n$$
简单选择排序|$$n^2$$|$$n^2$$|$$n^2$$|不稳定|1
归并排序|$$n\log_2 n$$|$$n\log_2 n$$|$$n\log_2 n$$|稳定|$$n$$
堆排序|$$n\log_2 n$$|$$n\log_2 n$$|$$n\log_2 n$$|稳定|1



```
package com.algorithm;

import org.junit.Test;

public class SortAlgorithm {
	@Test
	public void testPartition() {
		int[] arr = { 4, 3, 2, 5, 6, 1, 7, 8, 9 };
		int left = 0,right = arr.length-1;
		QuickSort(arr, left, right);
		show(arr);

		// SelectionSort(arr);
		// show(arr);

		// MergeSort(arr, 0, arr.length-1);
		// show(arr);

		HeapSort(arr, arr.length);
		show(arr);
	}

	/**
	 * 直接插入排序实现
	 */
	public void DirectInsertSort(int[] arr) {
		int length = arr.length;
		for (int i = 1; i < arr.length; i++) {
			int j = i - 1;
			// 本次欲插入的数据
			int temp = arr[i];
			while (j >= 0 && temp < arr[j]) {
				arr[j + 1] = arr[j];
				j--;
			}
			arr[j + 1] = temp;
		}
	}

	/**
	 * 折半插入排序算法
	 */
	public void BinaryInsertionSort(int[] arr) {
		int left, mid, right, p;
		for (p = 1; p < arr.length; p++) {
			int temp = arr[p];
			left = 0;
			right = p - 1;
			while (left <= right) {
				mid = (left + right) / 2;
				if (arr[mid] > temp)
					right = mid - 1;
				else
					left = mid + 1;
			}
			for (int i = p - 1; i >= left; i--) {
				arr[i + 1] = arr[i];
				arr[left] = temp;
			}
		}

	}

	/**
	 * 希尔排序
	 */
	public void ShellSort(int[] arr) {
		int d = arr.length / 2;
		while (d >= 1) {
			for (int k = 0; k < d; k++) {
				for (int i = k + d; i < arr.length; i += d) {
					int temp = arr[i];
					int j = i - d;
					while (j >= k && arr[j] > temp) {
						arr[j + d] = arr[j];
						j -= d;
					}
					arr[j + d] = temp;
				}
			}
			d = d / 2;
		}
	}

	/**
	 * 冒泡排序
	 */
	public void BubbleSort(int[] arr) {
		for (int i = 0; i < arr.length; i++) {
			for (int j = 1; j < arr.length - i; j++) {
				if (arr[j] < arr[j - 1]) {
					int temp = arr[j];
					arr[j] = arr[j - 1];
					arr[j - 1] = temp;
				}
			}
		}
	}

	/**
	 * 快速排序一(可以使用)
	 */
	public int Partition(int[] arr, int left, int right) {
		int pivot = arr[left];
		while (left < right) {
			while (left < right && arr[right] >= pivot) {
				right--;
			}
			if (left < right)
				arr[left++] = arr[right];
			while (left < right && arr[left] <= pivot) {
				left++;
			}
			if (left < right)
				arr[right--] = arr[left];
		}
		arr[left] = pivot;
		return left;
	}

	/**
	 * 快速排序二(仍需改正！！！！！！！！！！！)
	 */
	public int Partition2(int[] arr, int start, int end) {
		int pivot = arr[start];
		int left = start;
		int right = end;
		while (left <= right) {
			while (left <= right && arr[left] <= pivot) {
				left++;
			}
			while (left <= right && arr[right] >= pivot) {
				right++;
			}
			if (left < right) {
				swap(arr, left, right);
				left++;
				right--;
			}
		}
		swap(arr, start, right);
		return right;
	}

	/**
	 * 交换元素
	 */
	public void swap(int[] arr, int index1, int index2) {
		int temp = arr[index1];
		arr[index1] = arr[index2];
		arr[index2] = temp;
	}

	/**
	 * 快排测试
	 */
	public void QuickSort(int[] arr, int left, int right) {
		if (left < right) {
			int p = Partition(arr, left, right);
			QuickSort(arr, left, p - 1);
			QuickSort(arr, p + 1, right);
		}
	}

	public void show(int[] arr) {
		for (int i = 0; i < arr.length; i++) {
			System.out.println(arr[i]);
		}
	}

	/**
	 * 简单选择排序
	 */
	public void SelectionSort(int[] arr) {
		for (int i = 1; i < arr.length; i++) {
			int k = i - 1;
			for (int j = i; j < arr.length; j++) {
				if (arr[j] < arr[k])
					k = j;
			}
			if (k != i - 1) {
				int temp = arr[i - 1];
				arr[i - 1] = arr[k];
				arr[k] = temp;
			}
		}
	}

	/**
	 * 归并排序
	 */
	public void Merge(int[] arr, int left, int center, int right) {
		// 临时数组
		int[] tmpArr = new int[arr.length];
		// 右数组第一个元素索引
		int mid = center + 1;
		// third 记录临时数组的索引
		int third = left;
		// 缓存左数组第一个元素的索引
		int tmp = left;
		while (left <= center && mid <= right) {
			// 从两个数组中取出最小的放入临时数组
			if (arr[left] <= arr[mid]) {
				tmpArr[third++] = arr[left++];
			} else {
				tmpArr[third++] = arr[mid++];
			}
		}
		// 剩余部分依次放入临时数组（实际上两个while只会执行其中一个）
		while (mid <= right) {
			tmpArr[third++] = arr[mid++];
		}
		while (left <= center) {
			tmpArr[third++] = arr[left++];
		}
		// 将临时数组中的内容拷贝回原数组中
		// （原left-right范围的内容被复制回原数组）
		while (tmp <= right) {
			arr[tmp] = tmpArr[tmp++];
		}
	}

	public void MergeSort(int[] arr, int start, int end) {
		if (start < end) {
			int mid = (start + end) / 2;
			MergeSort(arr, start, mid);
			MergeSort(arr, mid + 1, end);
			Merge(arr, start, mid, end);
		}

	}

	/**
	 * 堆排序
	 */
	public void shiftDown(int[] arr,int i,int n){
		int left_c = 2*i+1;
		int right_c = 2*i+2;
		int min = i;
		if(left_c<n && arr[min]<arr[left_c]){
			min = left_c;
		}
		if(right_c<n && arr[min]<arr[right_c]){
			min = right_c;
		}
		if(min != i){
			swap(arr,min,i);
			shiftDown(arr, min, n);
		}
	}
	
	public void BuildHeap(int[] arr,int n){
		int p = n/2-1;
		for(int i=p;i>=0;i--){
			shiftDown(arr, i, n);
		}
	}
	
	public void HeapSort(int[] arr,int n){
		BuildHeap(arr, n);
		for(int i=n-1;i>0;i--){
			swap(arr, 0, i);
			BuildHeap(arr, i);
		}
		
	}

}

```