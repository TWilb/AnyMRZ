//
//  RecognitionDelegate.swift
//  AnyMRZ
//
//  Created by Bohdan Mihiliev on 29.06.2019.
//  Copyright © 2019 Bohdan Mihiliev. All rights reserved.
//
import UIKit
/**
 This is SKDs' main protocol to handle data and errors from recognition , detection processes.
 */
protocol RecognitionDelegate: class {
  
  /**
   This method indicates that operations has started.
   
   - parameter sender: Reader that began reading operations

  */
  func recognitionDidBegin(_ sender: ReaderOperation)
  
  /**
   This method will call when recognition procees
   is successfully finished and has some data.
   This method is going to call when recognized data from process is ready.

   - parameter sender: Reader that finsihed his reading operation
   - parameter data: This object includes all information from detected/recognized operation
   */
  
  func recognitionDidFinish(_ sender: ReaderOperation, with data: RecognizedData)
  
  /**
   This method will call when recognition procees did fail.
   This method is going to call when some SDK process did fail
   
   - parameter sender: Reader that failed
   - parameter error: This object includes all information about error
   
   */
  
  func recognitionDidFail(_ sender: ReaderOperation, with error: SDKError)

  /**
   This method indicates that next page of document should be scan.
   
   - parameter sender: Reader that is going to recognize next page
   - parameter currentPageData: Data from first page

   */
  func willRecognizeNextPage(_ sender: ReaderOperation, with currentPageData: RecognizedData)
}
/**
 This is SKDs' main protocol to handle data and errors from recognition , detection processes.
 */
public protocol ScanControollerDelegate: class {
  
  /**
   This method indicates that operations has started.
   
   - parameter sender: Reader that began reading operations
   
   */
  func recognitionDidBegin(_ sender: UIViewController)
  
  /**
   This method will call when recognition procees
   is successfully finished and has some data.
   This method is going to call when recognized data from process is ready.
   
   - parameter sender: Reader that finsihed his reading operation
   - parameter data: This object includes all information from detected/recognized operation
   */
  
  func recognitionDidFinish(_ sender: UIViewController, with data: RecognizedData)
  
  /**
   This method will call when recognition procees did fail.
   This method is going to call when some SDK process did fail
   
   - parameter sender: Reader that failed
   - parameter error: This object includes all information about error
   
   */
  
  func recognitionDidFail(_ sender: UIViewController, with error: SDKError)
  
  /**
   This method indicates that next page of document should be scan.
   
   - parameter sender: Reader that is going to recognize next page
   - parameter currentPageData: Data from first page
   
   */
  func willRecognizeNextPage(_ sender: UIViewController, with currentPageData: RecognizedData)
}
